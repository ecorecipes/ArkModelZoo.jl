struct InitModsocSystem <: System end

function initialize!(::InitModsocSystem, world::World)
    params = get_resource(world, ModsocSegParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, ModsocGrid)

    for x in 1:grid.width, y in 1:grid.height
        if rand(rng) < params.density
            is_yellow = rand(rng, Bool)
            eid = new_entity!(world, (
                ModsocPosition(x, y),
                ModsocColor(is_yellow),
                ModsocHappiness(),
            ))
            grid.cells[x, y] = eid
        end
    end
    _modsoc_update_happiness!(world)
    _modsoc_update_globals!(world)
    return nothing
end

function _modsoc_update_happiness!(world::World)
    params = get_resource(world, ModsocSegParams)
    grid = get_resource(world, ModsocGrid)

    for (_, positions, colors, happinesses) in Query(world, (ModsocPosition, ModsocColor, ModsocHappiness))
        @inbounds for i in eachindex(positions)
            pos = positions[i]
            col = colors[i]
            similar = 0
            total = 0
            for dx in -1:1, dy in -1:1
                (dx == 0 && dy == 0) && continue
                nx = mod1(pos.x + dx, grid.width)
                ny = mod1(pos.y + dy, grid.height)
                neid = grid.cells[nx, ny]
                is_zero(neid) && continue
                nc = get_components(world, neid, (ModsocColor,))[1]
                if nc.yellow == col.yellow
                    similar += 1
                end
                total += 1
            end
            prop = total == 0 ? 1.0 : similar / total
            happinesses[i].prop_similar = prop
            happinesses[i].happy = prop >= params.similarity_threshold
        end
    end
end

function _modsoc_update_globals!(world::World)
    stats = get_resource(world, ModsocStats)
    total_prop = 0.0
    n_agents = 0
    n_unhappy = 0
    for (_, _, _, happinesses) in Query(world, (ModsocPosition, ModsocColor, ModsocHappiness))
        @inbounds for i in eachindex(happinesses)
            total_prop += happinesses[i].prop_similar
            n_agents += 1
            if !happinesses[i].happy
                n_unhappy += 1
            end
        end
    end
    stats.average_similarity = n_agents > 0 ? total_prop / n_agents : 0.0
    stats.unhappiness = n_agents > 0 ? n_unhappy / n_agents : 0.0
end

struct ModsocMoveSystem <: System end

function update!(::ModsocMoveSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, ModsocGrid)

    # Collect unhappy agents
    unhappy = Tuple{Entity, Int, Int}[]
    for (eids, positions, _, happinesses) in Query(world, (ModsocPosition, ModsocColor, ModsocHappiness))
        @inbounds for i in eachindex(happinesses)
            if !happinesses[i].happy
                push!(unhappy, (eids[i], positions[i].x, positions[i].y))
            end
        end
    end
    Random.shuffle!(rng, unhappy)

    # Collect empty cells
    empty_cells = Tuple{Int,Int}[]
    for x in 1:grid.width, y in 1:grid.height
        if is_zero(grid.cells[x, y])
            push!(empty_cells, (x, y))
        end
    end

    for (eid, ox, oy) in unhappy
        isempty(empty_cells) && break
        idx = rand(rng, 1:length(empty_cells))
        nx, ny = empty_cells[idx]
        # Move
        grid.cells[ox, oy] = zero_entity
        grid.cells[nx, ny] = eid
        pos = get_components(world, eid, (ModsocPosition,))[1]
        pos.x = nx
        pos.y = ny
        # Old spot is now empty, new spot is taken
        empty_cells[idx] = (ox, oy)
    end

    _modsoc_update_happiness!(world)
    _modsoc_update_globals!(world)
    return nothing
end

struct ModsocTerminationSystem <: System end

function update!(::ModsocTerminationSystem, world::World)
    stats = get_resource(world, ModsocStats)
    params = get_resource(world, ModsocSegParams)
    tick = get_resource(world, Tick)

    if stats.unhappiness == 0.0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
