struct InitCrystSystem <: System end

function initialize!(::InitCrystSystem, world::World)
    params = get_resource(world, CrystallizationParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, CrystGrid)
    stats = get_resource(world, CrystStats)
    n = grid.metal_size

    for x in 1:n, y in 1:n
        grid.temp[x, y] = params.init_metal_temp
        grid.heading[x, y] = 0.0  # NetLogo default heading is 0
    end

    stats.ave_metal_temp = params.init_metal_temp
    stats.num_frozen = 0
    return nothing
end

# --- Cool ---

struct CrystCoolSystem <: System end

function update!(::CrystCoolSystem, world::World)
    params = get_resource(world, CrystallizationParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, CrystGrid)
    stats = get_resource(world, CrystStats)
    n = grid.metal_size
    temp = grid.temp

    # Early termination check: if max temp < melting-temp, stop BEFORE updating
    max_temp = -Inf
    for i in eachindex(temp)
        temp[i] > max_temp && (max_temp = temp[i])
    end
    if max_temp < params.melting_temp
        get_resource(world, Terminate).stop = true
        return nothing
    end

    # Cool turtles in random order (sequential, reads current temps)
    # NetLogo: neighboring-turtles includes self (at-points includes [0,0])
    # Formula: total-temp = sum(neighboring-turtles temps) + room-temp * sides-exposed + own-temp
    #          new-temp = total-temp / (count neighboring-turtles + sides-exposed + 1)
    # This counts self temp TWICE (in sum and in +temp), divisor is always 10
    perm = randperm(rng, n * n)
    for idx in perm
        y = (idx - 1) ÷ n + 1
        x = (idx - 1) % n + 1

        # Sum of current neighbor temps INCLUDING self (matching NetLogo's at-points with [0,0])
        neighbor_sum = temp[x, y]  # self included
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx, ny = x + dx, y + dy
            if 1 <= nx <= n && 1 <= ny <= n
                neighbor_sum += temp[nx, ny]
            end
        end

        # NetLogo adds own temp AGAIN: total = sum(neighbors+self) + room*exposed + temp
        total_temp = neighbor_sum + params.room_temp * grid.sides_exposed[x, y] + temp[x, y]
        # Divisor: count(neighbors+self) + sides_exposed + 1 = always 10
        divisor = (grid.neighbor_count[x, y] + 1) + grid.sides_exposed[x, y] + 1
        temp[x, y] = total_temp / divisor
    end

    return nothing
end

# --- Rotate ---

struct CrystRotateSystem <: System end

function update!(::CrystRotateSystem, world::World)
    params = get_resource(world, CrystallizationParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, CrystGrid)
    n = grid.metal_size
    temp = grid.temp
    heading = grid.heading

    # Check termination (may have been set in cool phase)
    term = get_resource(world, Terminate)
    term.stop && return nothing

    # Random order
    perm = randperm(rng, n * n)
    for idx in perm
        y = (idx - 1) ÷ n + 1
        x = (idx - 1) % n + 1

        temp[x, y] < params.melting_temp && continue  # only process non-frozen (temp >= melting)

        # Find frozen neighbors (temp <= melting_temp)
        # NetLogo: neighboring-turtles includes self via [0,0] offset
        frozen = Tuple{Int,Int}[]
        # Include self if frozen
        if temp[x, y] <= params.melting_temp
            push!(frozen, (x, y))
        end
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx, ny = x + dx, y + dy
            if 1 <= nx <= n && 1 <= ny <= n && temp[nx, ny] <= params.melting_temp
                push!(frozen, (nx, ny))
            end
        end

        if !isempty(frozen)
            fx, fy = frozen[rand(rng, 1:length(frozen))]
            heading[x, y] = heading[fx, fy]
        else
            heading[x, y] = mod(heading[x, y] + rand(rng) * 360.0, 360.0)
        end
    end
    return nothing
end

# --- Stats ---

struct CrystStatsSystem <: System end

function update!(::CrystStatsSystem, world::World)
    params = get_resource(world, CrystallizationParams)
    grid = get_resource(world, CrystGrid)
    stats = get_resource(world, CrystStats)
    temp = grid.temp

    total = 0.0
    nf = 0
    for i in eachindex(temp)
        total += temp[i]
        if temp[i] < params.melting_temp
            nf += 1
        end
    end
    n = grid.metal_size
    stats.ave_metal_temp = total / (n * n)
    stats.num_frozen = nf
    return nothing
end

# --- Termination ---

struct CrystTerminationSystem <: System end

function update!(::CrystTerminationSystem, world::World)
    params = get_resource(world, CrystallizationParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
