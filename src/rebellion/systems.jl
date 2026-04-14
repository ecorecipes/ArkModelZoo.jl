struct InitREBSystem <: System end

function initialize!(::InitREBSystem, world::World)
    params = get_resource(world, REBParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, REBGrid)
    w, h = grid.width, grid.height

    # Collect all cells
    all_cells = [(x, y) for x in 1:w for y in 1:h]
    Random.shuffle!(rng, all_cells)

    n_patches = w * h
    n_cops = round(Int, params.initial_cop_density * 0.01 * n_patches)
    n_agents = round(Int, params.initial_agent_density * 0.01 * n_patches)

    idx = 1
    for _ in 1:n_cops
        x, y = all_cells[idx]; idx += 1
        eid = new_entity!(world, (REBCop(x, y),))
        grid.cells[x, y] = eid
    end

    for _ in 1:n_agents
        x, y = all_cells[idx]; idx += 1
        ra = rand(rng)
        ph = rand(rng)
        eid = new_entity!(world, (REBAgent(x, y, ra, ph, false, 0),))
        grid.cells[x, y] = eid
    end

    _reb_update_stats!(world)
    return nothing
end

struct REBGoSystem <: System end

function update!(::REBGoSystem, world::World)
    params = get_resource(world, REBParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, REBGrid)

    # Collect all turtles (agents + cops) with shuffled ask
    agents_list = Tuple{Entity, REBAgent}[]
    cops_list = Tuple{Entity, REBCop}[]
    for (eids, agents) in Query(world, (REBAgent,))
        @inbounds for i in eachindex(agents)
            push!(agents_list, (eids[i], agents[i]))
        end
    end
    for (eids, cops) in Query(world, (REBCop,))
        @inbounds for i in eachindex(cops)
            push!(cops_list, (eids[i], cops[i]))
        end
    end

    # Build combined list for "ask turtles" — agents and cops interleaved
    all_turtles = Vector{Tuple{Symbol, Int}}()
    for i in eachindex(agents_list)
        push!(all_turtles, (:agent, i))
    end
    for i in eachindex(cops_list)
        push!(all_turtles, (:cop, i))
    end
    Random.shuffle!(rng, all_turtles)

    for (kind, idx) in all_turtles
        if kind == :agent
            _, ag = agents_list[idx]
            # Move (if not jailed)
            if ag.jail_term == 0
                _reb_move!(rng, ag, grid, params, world)
            end
            # Determine behavior
            if ag.jail_term == 0
                grievance = ag.perceived_hardship * (1.0 - params.government_legitimacy)
                # Count cops and active agents in neighborhood
                nb = grid.neighborhoods[ag.x, ag.y]
                n_cops = 0; n_active = 0
                for (nx, ny) in nb
                    neid = grid.cells[nx, ny]
                    is_zero(neid) && continue
                    if has_components(world, neid, (REBCop,))
                        n_cops += 1
                    elseif has_components(world, neid, (REBAgent,))
                        nag = get_components(world, neid, (REBAgent,))[1]
                        if nag.active
                            n_active += 1
                        end
                    end
                end
                a_count = 1 + n_active
                arrest_prob = 1.0 - exp(-params.k * floor(n_cops / a_count))
                ag.active = (grievance - ag.risk_aversion * arrest_prob > params.threshold)
            end
        else  # cop
            _, cop = cops_list[idx]
            _reb_cop_move!(rng, cop, grid, params, world)
            # Enforce: arrest a random active agent in vision
            nb = grid.neighborhoods[cop.x, cop.y]
            active_in_vision = Tuple{Int,Int}[]
            for (nx, ny) in nb
                neid = grid.cells[nx, ny]
                is_zero(neid) && continue
                if has_components(world, neid, (REBAgent,))
                    nag = get_components(world, neid, (REBAgent,))[1]
                    if nag.active
                        push!(active_in_vision, (nx, ny))
                    end
                end
            end
            if !isempty(active_in_vision)
                sx, sy = active_in_vision[rand(rng, 1:length(active_in_vision))]
                seid = grid.cells[sx, sy]
                suspect = get_components(world, seid, (REBAgent,))[1]
                suspect.active = false
                suspect.jail_term = rand(rng, 0:max(params.max_jail_term - 1, 0))
                # Cop moves to suspect's patch
                grid.cells[cop.x, cop.y] = zero_entity
                cop.x = sx; cop.y = sy
                # Suspect stays but is jailed (they share cell briefly)
            end
        end
    end

    # Decrement jail terms
    for (_, ag) in agents_list
        if ag.jail_term > 0
            ag.jail_term -= 1
        end
    end

    _reb_update_stats!(world)
    return nothing
end

function _reb_move!(rng, ag::REBAgent, grid::REBGrid, params::REBParams, world::World)
    params.movement || return
    nb = grid.neighborhoods[ag.x, ag.y]
    targets = Tuple{Int,Int}[]
    for (nx, ny) in nb
        eid = grid.cells[nx, ny]
        if is_zero(eid)
            push!(targets, (nx, ny))
        elseif has_components(world, eid, (REBAgent,))
            nag = get_components(world, eid, (REBAgent,))[1]
            if nag.jail_term > 0
                push!(targets, (nx, ny))
            end
        end
    end
    isempty(targets) && return
    tx, ty = targets[rand(rng, 1:length(targets))]
    # Only move to truly empty cells (not just jailed — simplification for grid)
    if is_zero(grid.cells[tx, ty])
        grid.cells[ag.x, ag.y] = zero_entity
        grid.cells[tx, ty] = _reb_find_entity(world, ag)
        ag.x = tx; ag.y = ty
    end
end

function _reb_cop_move!(rng, cop::REBCop, grid::REBGrid, params::REBParams, world::World)
    nb = grid.neighborhoods[cop.x, cop.y]
    targets = Tuple{Int,Int}[]
    for (nx, ny) in nb
        eid = grid.cells[nx, ny]
        if is_zero(eid)
            push!(targets, (nx, ny))
        end
    end
    isempty(targets) && return
    tx, ty = targets[rand(rng, 1:length(targets))]
    eid_cop = grid.cells[cop.x, cop.y]
    grid.cells[cop.x, cop.y] = zero_entity
    grid.cells[tx, ty] = eid_cop
    cop.x = tx; cop.y = ty
end

function _reb_find_entity(world::World, ag::REBAgent)
    # Find the entity for this agent by scanning
    for (eids, agents) in Query(world, (REBAgent,))
        @inbounds for i in eachindex(agents)
            if agents[i] === ag
                return eids[i]
            end
        end
    end
    return zero_entity
end

function _reb_update_stats!(world::World)
    stats = get_resource(world, REBStats)
    nq = 0; na = 0; nj = 0
    for (_, agents) in Query(world, (REBAgent,))
        @inbounds for i in eachindex(agents)
            ag = agents[i]
            if ag.jail_term > 0
                nj += 1
            elseif ag.active
                na += 1
            else
                nq += 1
            end
        end
    end
    stats.num_quiet = nq
    stats.num_active = na
    stats.num_jailed = nj
end

struct REBTerminationSystem <: System end

function update!(::REBTerminationSystem, world::World)
    params = get_resource(world, REBParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
