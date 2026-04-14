# Spatial Opinion Dynamics — ECS systems

function _sopn_influence_function(influence::String, val::Int, max_entrench::Int)
    if influence == "linear"
        return val == 0 ? 1.0 : Float64(abs(val))
    elseif influence == "square"
        return val == 0 ? 1.0 : Float64(val^2)
    elseif influence == "uniform"
        if val < 0; return 1.0; end
        if val > 0; return 1.0; end
        return 1.0
    elseif influence == "co-linear"
        return val == 0 ? 1.0 : Float64(max_entrench + 1 - abs(val))
    elseif influence == "co-square"
        return val == 0 ? 1.0 : Float64((max_entrench + 1 - abs(val))^2)
    end
    return 1.0
end

# Wrapping Moore neighbors for a grid indexed 1:w, 1:h
function _sopn_neighbors_wrap(x::Int, y::Int, w::Int, h::Int)
    nbrs = Tuple{Int,Int}[]
    for dx in -1:1, dy in -1:1
        (dx == 0 && dy == 0) && continue
        nx = mod1(x + dx, w)
        ny = mod1(y + dy, h)
        push!(nbrs, (nx, ny))
    end
    return nbrs
end

struct InitSOpnSystem <: System end

function initialize!(::InitSOpnSystem, world::World)
    params = get_resource(world, SOpnParams)
    rng    = get_resource(world, RNGResource).rng
    grid   = get_resource(world, SOpnGrid)
    stats  = get_resource(world, SOpnStats)
    w, h = grid.width, grid.height

    if params.rnd_initial
        for x in 1:w, y in 1:h
            if rand(rng) < params.positive_to_negative_ratio
                grid.new_attitude[x, y] = rand(rng, 1:params.init_attitude)
            else
                grid.new_attitude[x, y] = -(rand(rng, 1:params.init_attitude))
            end
        end
    else
        cx = (w + 1) / 2.0
        cy = (h + 1) / 2.0
        for x in 1:w, y in 1:h
            dx = x - cx
            dy = y - cy
            if dx^2 + dy^2 <= params.radius_size^2
                grid.new_attitude[x, y] = params.max_entrench
            else
                grid.new_attitude[x, y] = -params.max_entrench
            end
        end
    end

    # old_attitude = new_attitude after setup
    copyto!(grid.old_attitude, grid.new_attitude)
    stats.fizz = 0.0
    _sopn_measure_freq!(grid, stats)
    return nothing
end

function _sopn_measure_freq!(grid::SOpnGrid, stats::SOpnStats)
    n = grid.width * grid.height
    left_count = 0
    right_count = 0
    for x in 1:grid.width, y in 1:grid.height
        v = grid.old_attitude[x, y]
        if v <= -1; left_count += 1; end
        if v >= 1; right_count += 1; end
    end
    stats.left_freq = left_count / n
    stats.right_freq = right_count / n
end

struct SOpnGoSystem <: System end

function update!(::SOpnGoSystem, world::World)
    params = get_resource(world, SOpnParams)
    rng    = get_resource(world, RNGResource).rng
    grid   = get_resource(world, SOpnGrid)
    stats  = get_resource(world, SOpnStats)
    w, h = grid.width, grid.height

    # ask turtles [local-interactions] — shuffle all cells
    cells = [(x, y) for x in 1:w for y in 1:h]
    shuffle!(rng, cells)

    for (x, y) in cells
        nbrs = _sopn_neighbors_wrap(x, y, w, h)
        isempty(nbrs) && continue
        my_old = grid.old_attitude[x, y]

        # Build weighted pair list from neighbors
        localsum = 0.0
        for (nx, ny) in nbrs
            localsum += abs(_sopn_influence_function(params.influence, grid.old_attitude[nx, ny], params.max_entrench))
        end

        if localsum == 0.0
            continue
        end

        # Weighted selection of neighbor j
        weights = Float64[abs(_sopn_influence_function(params.influence, grid.old_attitude[nx, ny], params.max_entrench)) for (nx, ny) in nbrs]
        j_idx = weighted_one_of(rng, collect(1:length(nbrs)), weights)
        jx, jy = nbrs[j_idx]
        j_old = grid.old_attitude[jx, jy]

        if rand(rng) < params.opinion_amplification
            # Opinion amplification
            if j_old > 0
                if abs(my_old) < params.max_entrench
                    if my_old == -1
                        grid.new_attitude[x, y] = 1
                    else
                        grid.new_attitude[x, y] = my_old + 1
                    end
                end
            end
            if j_old < 0
                if abs(my_old) < params.max_entrench
                    if my_old == 1
                        grid.new_attitude[x, y] = -1
                    else
                        grid.new_attitude[x, y] = my_old - 1
                    end
                end
            end
        else
            # Convergence
            if j_old > my_old
                if my_old == -1
                    grid.new_attitude[x, y] = 1
                else
                    grid.new_attitude[x, y] = my_old + 1
                end
            end
            if j_old < my_old
                if my_old == 1
                    grid.new_attitude[x, y] = -1
                else
                    grid.new_attitude[x, y] = my_old - 1
                end
            end
        end
    end

    # Compute fizz BEFORE updating old_attitude
    n = w * h
    changed = 0
    for x in 1:w, y in 1:h
        if grid.old_attitude[x, y] != grid.new_attitude[x, y]
            changed += 1
        end
    end
    stats.fizz = changed / n

    # Update old_attitude = new_attitude
    copyto!(grid.old_attitude, grid.new_attitude)
    _sopn_measure_freq!(grid, stats)
    return nothing
end

struct SOpnTerminationSystem <: System end

function update!(::SOpnTerminationSystem, world::World)
    params = get_resource(world, SOpnParams)
    tick   = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
