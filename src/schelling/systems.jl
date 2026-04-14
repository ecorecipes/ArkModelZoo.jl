# Schelling Segregation — classic teleportation variant
# 51×51 wrapping grid, 70% density, red/blue, 30% threshold

struct InitSchSystem <: System end

function initialize!(::InitSchSystem, world::World)
    params = get_resource(world, SchParams)
    rng    = get_resource(world, RNGResource).rng
    grid   = get_resource(world, SchGrid)

    for x in 1:grid.width, y in 1:grid.height
        if rand(rng, 0:99) < round(Int, params.density)
            is_red = rand(rng, Bool)
            eid = new_entity!(world, (SchPosition(x, y), SchColor(is_red), SchHappiness()))
            _sch_set_cell!(grid, x, y, eid)
        end
    end

    # Initial happiness computation
    update!(SchUpdateHappinessSystem(), world)
    return nothing
end

# --- Happiness computation ---
struct SchUpdateHappinessSystem <: System end

function update!(::SchUpdateHappinessSystem, world::World)
    params = get_resource(world, SchParams)
    grid   = get_resource(world, SchGrid)
    stats  = get_resource(world, SchStats)

    total_similar  = 0
    total_neighbors = 0
    num_unhappy    = 0
    num_agents     = 0

    for (_, positions, colors, happinesses) in Query(world, (SchPosition, SchColor, SchHappiness))
        @inbounds for i in eachindex(positions)
            pos   = positions[i]
            color = colors[i]
            h     = happinesses[i]

            similar = 0
            other   = 0
            for dx in -1:1, dy in -1:1
                (dx == 0 && dy == 0) && continue
                nx = mod1(pos.x + dx, grid.width)
                ny = mod1(pos.y + dy, grid.height)
                neighbor_eid = grid.cells[nx, ny]
                is_zero(neighbor_eid) && continue
                nc = get_components(world, neighbor_eid, (SchColor,))[1]
                if nc.red == color.red
                    similar += 1
                else
                    other += 1
                end
            end

            total = similar + other
            h.similar_nearby = similar
            h.other_nearby   = other
            h.total_nearby   = total
            h.happy = total == 0 || (similar / total * 100.0 >= params.pct_similar_wanted)

            if !h.happy
                num_unhappy += 1
            end
            num_agents += 1
            total_similar  += similar
            total_neighbors += total
        end
    end

    stats.percent_unhappy = num_agents > 0 ? num_unhappy / num_agents * 100.0 : 0.0
    stats.percent_similar = total_neighbors > 0 ? total_similar / total_neighbors * 100.0 : 0.0
    return nothing
end

# --- Move unhappy agents (teleport to random empty patch) ---
struct SchMoveUnhappySystem <: System end

function update!(::SchMoveUnhappySystem, world::World)
    rng  = get_resource(world, RNGResource).rng
    grid = get_resource(world, SchGrid)

    # Collect empty patches
    empty_patches = Tuple{Int,Int}[]
    for x in 1:grid.width, y in 1:grid.height
        if _sch_is_empty(grid, x, y)
            push!(empty_patches, (x, y))
        end
    end

    # Collect unhappy agents
    unhappy = Tuple{Entity, Int, Int}[]
    for (eids, positions, _, happinesses) in Query(world, (SchPosition, SchColor, SchHappiness))
        @inbounds for i in eachindex(positions)
            if !happinesses[i].happy
                push!(unhappy, (eids[i], positions[i].x, positions[i].y))
            end
        end
    end

    shuffle!(rng, unhappy)

    for (eid, ox, oy) in unhappy
        isempty(empty_patches) && break
        # Pick random empty patch
        idx = rand(rng, 1:length(empty_patches))
        nx, ny = empty_patches[idx]

        # Swap: old cell becomes empty, new cell gets agent
        _sch_clear_cell!(grid, ox, oy)
        _sch_set_cell!(grid, nx, ny, eid)

        pos = get_components(world, eid, (SchPosition,))[1]
        pos.x = nx
        pos.y = ny

        # Update empty list: remove used patch, add old patch
        empty_patches[idx] = (ox, oy)
    end
    return nothing
end

# --- Termination ---
struct SchTerminationSystem <: System end

function update!(::SchTerminationSystem, world::World)
    params = get_resource(world, SchParams)
    tick   = get_resource(world, Tick)
    stats  = get_resource(world, SchStats)
    if stats.percent_unhappy == 0.0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
