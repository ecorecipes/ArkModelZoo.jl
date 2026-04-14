# --- Initialization ---

struct InitEthnoSystem <: System end

function _random_ethno_agent!(world::World, rng, params::EthnocentrismParams,
                               grid::EthnoGrid, x::Int, y::Int)
    color = rand(rng, 1:4)
    coop_same = rand(rng) < params.immigrant_chance_cooperate_same
    coop_diff = rand(rng) < params.immigrant_chance_cooperate_different
    eid = new_entity!(world, (
        EthnoPosition(x, y),
        Strategy(coop_same, coop_diff),
        EthnoColor(color),
        PTR(0.0),
    ))
    grid.cells[x, y] = eid
    return eid
end

function initialize!(::InitEthnoSystem, world::World)
    params = get_resource(world, EthnocentrismParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, EthnoGrid)

    if params.start_full
        for x in 1:grid.width, y in 1:grid.height
            _random_ethno_agent!(world, rng, params, grid, x, y)
        end
    end
    return nothing
end

# --- Immigration ---

struct ImmigrationSystem <: System end

function update!(::ImmigrationSystem, world::World)
    params = get_resource(world, EthnocentrismParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, EthnoGrid)

    # Collect empty cells
    empties = Tuple{Int,Int}[]
    for x in 1:grid.width, y in 1:grid.height
        is_zero(grid.cells[x, y]) && push!(empties, (x, y))
    end

    isempty(empties) && return nothing

    for _ in 1:params.immigrants_per_day
        isempty(empties) && break
        idx = rand(rng, 1:length(empties))
        x, y = empties[idx]
        _random_ethno_agent!(world, rng, params, grid, x, y)
        deleteat!(empties, idx)
    end
    return nothing
end

# --- Interaction ---

struct InteractionSystem <: System end

function update!(::InteractionSystem, world::World)
    params = get_resource(world, EthnocentrismParams)
    grid = get_resource(world, EthnoGrid)
    stats = get_resource(world, EthnoStats)
    clear_tick_stats!(stats)
    w, h = grid.width, grid.height

    # Set PTR to initial value for all agents
    for (_, _, ptrs) in Query(world, (EthnoPosition, PTR))
        @inbounds for i in eachindex(ptrs)
            ptrs[i].value = params.initial_ptr
        end
    end

    # Von Neumann neighbors (N, S, E, W)
    offsets = [(0, 1), (0, -1), (1, 0), (-1, 0)]

    for (eids, positions, strategies, colors, ptrs) in Query(world, (EthnoPosition, Strategy, EthnoColor, PTR))
        @inbounds for i in eachindex(positions)
            pos = positions[i]
            my_color = colors[i].color
            my_strategy = strategies[i]

            for (dx, dy) in offsets
                nx = pos.x + dx
                ny = pos.y + dy
                # Wrap toroidal
                nx = mod1(nx, w)
                ny = mod1(ny, h)

                neighbor_eid = grid.cells[nx, ny]
                is_zero(neighbor_eid) && continue

                stats.meet += 1
                neighbor_color = get_components(world, neighbor_eid, (EthnoColor,))[1]
                neighbor_ptr = get_components(world, neighbor_eid, (PTR,))[1]
                same_group = my_color == neighbor_color.color

                if same_group
                    stats.meetown += 1
                    if my_strategy.cooperate_with_same
                        ptrs[i].value -= params.cost_of_giving
                        neighbor_ptr.value += params.gain_of_receiving
                        stats.coopown += 1
                    end
                else
                    stats.meetother += 1
                    if my_strategy.cooperate_with_different
                        ptrs[i].value -= params.cost_of_giving
                        neighbor_ptr.value += params.gain_of_receiving
                        stats.coopother += 1
                    else
                        stats.defother += 1
                    end
                end
            end
        end
    end
    return nothing
end

# --- Reproduction ---

mutable struct EthnoReproductionSystem <: System
    to_spawn::Vector{Tuple{Int, Int, Int, Bool, Bool}}  # (x, y, color, coop_same, coop_diff)
end
EthnoReproductionSystem() = EthnoReproductionSystem(Tuple{Int,Int,Int,Bool,Bool}[])

function update!(system::EthnoReproductionSystem, world::World)
    params = get_resource(world, EthnocentrismParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, EthnoGrid)
    w, h = grid.width, grid.height
    offsets = [(0, 1), (0, -1), (1, 0), (-1, 0)]

    empty!(system.to_spawn)

    for (_, positions, strategies, colors, ptrs) in Query(world, (EthnoPosition, Strategy, EthnoColor, PTR))
        @inbounds for i in eachindex(positions)
            ptrs[i].value <= 0.0 && continue
            rand(rng) >= ptrs[i].value && continue

            # Find empty neighbor
            pos = positions[i]
            neighbors = Tuple{Int,Int}[]
            for (dx, dy) in offsets
                nx = mod1(pos.x + dx, w)
                ny = mod1(pos.y + dy, h)
                is_zero(grid.cells[nx, ny]) && push!(neighbors, (nx, ny))
            end
            isempty(neighbors) && continue

            nx, ny = neighbors[rand(rng, 1:length(neighbors))]

            # Offspring inherits parent traits with mutation
            child_color = colors[i].color
            child_coop_same = strategies[i].cooperate_with_same
            child_coop_diff = strategies[i].cooperate_with_different

            if rand(rng) < params.mutation_rate
                child_color = rand(rng, 1:4)
            end
            if rand(rng) < params.mutation_rate
                child_coop_same = !child_coop_same
            end
            if rand(rng) < params.mutation_rate
                child_coop_diff = !child_coop_diff
            end

            push!(system.to_spawn, (nx, ny, child_color, child_coop_same, child_coop_diff))
        end
    end

    for (x, y, color, cs, cd) in system.to_spawn
        !is_zero(grid.cells[x, y]) && continue
        eid = new_entity!(world, (
            EthnoPosition(x, y),
            Strategy(cs, cd),
            EthnoColor(color),
            PTR(0.0),
        ))
        grid.cells[x, y] = eid
    end
    return nothing
end

# --- Death ---

struct EthnoDeathSystem <: System
    to_remove::Vector{Entity}
end
EthnoDeathSystem() = EthnoDeathSystem(Entity[])

function update!(system::EthnoDeathSystem, world::World)
    params = get_resource(world, EthnocentrismParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, EthnoGrid)
    empty!(system.to_remove)

    for (eids, positions) in Query(world, (EthnoPosition,))
        @inbounds for i in eachindex(positions)
            if rand(rng) < params.death_rate
                push!(system.to_remove, eids[i])
            end
        end
    end

    for e in system.to_remove
        if is_alive(world, e)
            pos = get_components(world, e, (EthnoPosition,))[1]
            grid.cells[pos.x, pos.y] = zero_entity
            remove_entity!(world, e)
        end
    end
    return nothing
end

# --- Statistics ---

struct EthnoStatsSystem <: System end

function update!(::EthnoStatsSystem, world::World)
    stats = get_resource(world, EthnoStats)
    cc = 0; cd = 0; dc = 0; dd = 0; total = 0

    for (_, _, strategies) in Query(world, (EthnoPosition, Strategy))
        @inbounds for i in eachindex(strategies)
            total += 1
            s = strategies[i]
            if s.cooperate_with_same && s.cooperate_with_different
                cc += 1  # altruist
            elseif s.cooperate_with_same && !s.cooperate_with_different
                cd += 1  # ethnocentric
            elseif !s.cooperate_with_same && s.cooperate_with_different
                dc += 1  # cosmopolitan
            else
                dd += 1  # egoist
            end
        end
    end

    stats.total_population = total
    if total > 0
        push!(stats.cc_history, cc / total * 100.0)
        push!(stats.cd_history, cd / total * 100.0)
        push!(stats.dc_history, dc / total * 100.0)
        push!(stats.dd_history, dd / total * 100.0)
        # Keep rolling window of 100
        if length(stats.cc_history) > 100
            popfirst!(stats.cc_history)
            popfirst!(stats.cd_history)
            popfirst!(stats.dc_history)
            popfirst!(stats.dd_history)
        end
    end
    return nothing
end

# --- Termination ---

struct EthnoTerminationSystem <: System end

function update!(::EthnoTerminationSystem, world::World)
    params = get_resource(world, EthnocentrismParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
