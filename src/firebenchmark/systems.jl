struct InitFBSystem <: System end

function initialize!(::InitFBSystem, world::World)
    params = get_resource(world, FBParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, FBGrid)
    stats = get_resource(world, FBStats)

    # Plant trees: columns 3+ (pxcor > 1 + min-pxcor, i.e. pxcor > -39, grid col > 2)
    for x in 3:grid.width, y in 1:grid.height
        if rand(rng, 0:99) < params.density
            grid.tree[x, y] = true
        end
    end

    # Column 2 (pxcor = 1 + min-pxcor = -39): start fire wall
    for y in 1:grid.height
        grid.heat[2, y] = 14
        grid.fire_front[2, y] = true
    end

    stats.initial_trees = count(grid.tree)
    stats.burned_trees = 0

    # Count initial burning
    stats.burning_count = 0
    for x in 1:grid.width, y in 1:grid.height
        if grid.heat[x, y] > 0
            stats.burning_count += 1
        end
    end
    return nothing
end

struct FBStepSystem <: System end

function update!(::FBStepSystem, world::World)
    grid = get_resource(world, FBGrid)
    stats = get_resource(world, FBStats)

    # Only fire-front patches spread to tree neighbors4
    # (NetLogo: ask fire-front [...]; fire-front = most recently ignited patches)
    # Use torus wrapping (NetLogo default topology)
    fill!(grid.next_fire, false)
    for x in 1:grid.width, y in 1:grid.height
        grid.fire_front[x, y] || continue
        for (dx, dy) in ((0, 1), (0, -1), (1, 0), (-1, 0))
            nx = mod1(x + dx, grid.width)
            ny = mod1(y + dy, grid.height)
            if grid.tree[nx, ny]
                grid.next_fire[nx, ny] = true
            end
        end
    end

    # New fire front: set heat=14, tree=false
    new_fire_count = 0
    for x in 1:grid.width, y in 1:grid.height
        if grid.next_fire[x, y]
            grid.tree[x, y] = false
            grid.heat[x, y] = 14
            new_fire_count += 1
        end
    end

    # Burning front loses heat (all patches with heat > 0, EXCLUDING new fire front)
    for x in 1:grid.width, y in 1:grid.height
        if grid.heat[x, y] > 0 && !grid.next_fire[x, y]
            grid.heat[x, y] -= 1
        end
    end

    stats.burned_trees += new_fire_count

    # Update fire front: only newly ignited patches spread next tick
    fill!(grid.fire_front, false)
    for x in 1:grid.width, y in 1:grid.height
        if grid.next_fire[x, y]
            grid.fire_front[x, y] = true
        end
    end

    # Count total burning (burning_front = new fire + still-burning old patches)
    stats.burning_count = 0
    for x in 1:grid.width, y in 1:grid.height
        if grid.heat[x, y] > 0
            stats.burning_count += 1
        end
    end
    return nothing
end

struct FBTerminationSystem <: System end

function update!(::FBTerminationSystem, world::World)
    stats = get_resource(world, FBStats)
    params = get_resource(world, FBParams)
    tick = get_resource(world, Tick)

    if stats.burning_count == 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
