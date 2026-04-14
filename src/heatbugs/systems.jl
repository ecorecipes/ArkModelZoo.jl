# --- Initialization ---

struct InitHBSystem <: System end

function initialize!(::InitHBSystem, world::World)
    params = get_resource(world, HBParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, HBGrid)

    # Place bugs on random unique patches (n-of bug-count patches)
    all_patches = [(x, y) for x in 1:grid.width for y in 1:grid.height]
    Random.shuffle!(rng, all_patches)
    n = min(params.bug_count, length(all_patches))
    for i in 1:n
        x, y = all_patches[i]
        ideal = params.min_ideal_temp + Float64(rand(rng, 0:Int(params.max_ideal_temp - params.min_ideal_temp) - 1))
        output = params.min_output_heat + Float64(rand(rng, 0:Int(params.max_output_heat - params.min_output_heat) - 1))
        unhappy = abs(ideal - grid.temp[x, y])
        eid = new_entity!(world, (HBPos(x, y), HBBug(ideal, output, unhappy)))
        grid.cells[x, y] = eid
    end
    return nothing
end

# --- Diffuse and Evaporate ---

struct HBDiffuseSystem <: System end

function update!(::HBDiffuseSystem, world::World)
    params = get_resource(world, HBParams)
    grid = get_resource(world, HBGrid)
    w, h = grid.width, grid.height
    rate = params.diffusion_rate

    # NetLogo diffuse: each patch shares rate/8 of its value with each of 8 neighbors
    old_temp = copy(grid.temp)
    share = rate / 8.0
    for x in 1:w, y in 1:h
        lost = old_temp[x, y] * rate
        grid.temp[x, y] -= lost
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = mod1(x + dx, w)
            ny = mod1(y + dy, h)
            grid.temp[nx, ny] += old_temp[x, y] * share
        end
    end

    # Evaporation
    evap = 1.0 - params.evaporation_rate
    for i in eachindex(grid.temp)
        grid.temp[i] *= evap
    end
    return nothing
end

# --- Bug Step ---

struct HBGoSystem <: System end

function update!(::HBGoSystem, world::World)
    params = get_resource(world, HBParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, HBGrid)
    stats = get_resource(world, HBStats)
    w, h = grid.width, grid.height

    # Collect all bugs
    bugs = Tuple{Entity, Int, Int}[]
    for (eids, positions, bugdata) in Query(world, (HBPos, HBBug))
        @inbounds for i in eachindex(positions)
            push!(bugs, (eids[i], positions[i].x, positions[i].y))
        end
    end

    Random.shuffle!(rng, bugs)

    total_unhappy = 0.0
    max_unhappy = 0.0

    for (eid, ox, oy) in bugs
        bug = get_components(world, eid, (HBBug,))[1]
        pos = get_components(world, eid, (HBPos,))[1]
        # Compute unhappiness
        bug.unhappiness = abs(bug.ideal_temp - grid.temp[pos.x, pos.y])

        if bug.unhappiness > 0
            if rand(rng) * 100.0 < params.random_move_chance
                # Random move to any neighbor
                target = _hb_random_neighbor(rng, pos.x, pos.y, w, h)
                _hb_bug_move!(grid, world, eid, pos, target, rng)
            else
                # Move to best patch
                target = _hb_best_patch(bug, grid, pos.x, pos.y, w, h)
                _hb_bug_move!(grid, world, eid, pos, target, rng)
            end
        end

        # Output heat
        grid.temp[pos.x, pos.y] += bug.output_heat

        total_unhappy += bug.unhappiness
        max_unhappy = max(max_unhappy, bug.unhappiness)
    end

    n = length(bugs)
    stats.mean_unhappiness = n > 0 ? total_unhappy / n : 0.0
    stats.max_unhappiness = max_unhappy
    return nothing
end

function _hb_random_neighbor(rng, x::Int, y::Int, w::Int, h::Int)
    offsets = ((-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1))
    dx, dy = offsets[rand(rng, 1:8)]
    return (mod1(x + dx, w), mod1(y + dy, h))
end

function _hb_best_patch(bug::HBBug, grid::HBGrid, x::Int, y::Int, w::Int, h::Int)
    if grid.temp[x, y] < bug.ideal_temp
        # Want hotter: find hottest neighbor
        best = (x, y)
        best_temp = grid.temp[x, y]
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = mod1(x + dx, w)
            ny = mod1(y + dy, h)
            t = grid.temp[nx, ny]
            if t > best_temp
                best_temp = t
                best = (nx, ny)
            end
        end
        return best
    else
        # Want cooler: find coolest neighbor
        best = (x, y)
        best_temp = grid.temp[x, y]
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = mod1(x + dx, w)
            ny = mod1(y + dy, h)
            t = grid.temp[nx, ny]
            if t < best_temp
                best_temp = t
                best = (nx, ny)
            end
        end
        return best
    end
end

function _hb_bug_move!(grid::HBGrid, world::World, eid::Entity, pos::HBPos, target::Tuple{Int,Int}, rng)
    tx, ty = target
    # Already here?
    (tx == pos.x && ty == pos.y) && return
    w, h = grid.width, grid.height
    # Target not occupied?
    if hb_is_empty(grid, tx, ty)
        grid.cells[pos.x, pos.y] = zero_entity
        grid.cells[tx, ty] = eid
        pos.x = tx
        pos.y = ty
        return
    end
    # Try any empty neighbor
    neighbors = Tuple{Int,Int}[]
    for dx in -1:1, dy in -1:1
        (dx == 0 && dy == 0) && continue
        nx = mod1(pos.x + dx, w)
        ny = mod1(pos.y + dy, h)
        if hb_is_empty(grid, nx, ny)
            push!(neighbors, (nx, ny))
        end
    end
    if !isempty(neighbors)
        nx, ny = neighbors[rand(rng, 1:length(neighbors))]
        grid.cells[pos.x, pos.y] = zero_entity
        grid.cells[nx, ny] = eid
        pos.x = nx
        pos.y = ny
    end
end

# --- Termination ---

struct HBTerminationSystem <: System end

function update!(::HBTerminationSystem, world::World)
    params = get_resource(world, HBParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
