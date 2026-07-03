# Fire model systems matching NetLogo Forest Fire
# Execution order: init → spread fires → fade embers → count/terminate

# --- Initialization ---
# NetLogo: ask patches [if random-float 100 < density → green]
#          ask patches with [pxcor = min-pxcor] [ ignite ]

struct InitFireSystem <: System end

function initialize!(::InitFireSystem, world::World)
    params = get_resource(world, FireParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, FireGrid)
    stats = get_resource(world, FireStats)

    # Plant trees: each patch has density% chance of being a tree
    # NetLogo: random-float 100 < density (continuous random, not integer)
    for x in 1:grid.width, y in 1:grid.height
        if rand(rng) * 100.0 < params.density
            grid.state[x, y] = 1  # tree (green)
        end
    end

    stats.initial_trees = count(==(1), grid.state)

    # Ignite left column (pxcor = min-pxcor = -125 → grid x=1)
    # NetLogo: ask patches with [pxcor = min-pxcor] [ ignite ]
    # ALL left-column patches are ignited, not just trees
    for y in 1:grid.height
        _ignite!(world, grid, stats, 1, y)
    end

    # NetLogo: set burned-trees 0 (ignition during setup doesn't count)
    stats.burned_trees = 0
    return nothing
end

# Ignite a patch: create fire entity, mark patch burned, increment count
function _ignite!(world::World, grid::FireGrid, stats::FireStats, x::Int, y::Int)
    new_entity!(world, (FirePosition(x, y), FireTag()))
    grid.state[x, y] = 2  # burned (black)
    stats.burned_trees += 1
    return nothing
end

# --- Fire Spread ---
# NetLogo: ask fires [ ask neighbors4 with [pcolor = green] [ ignite ] ; set breed embers ]

struct FireSpreadSystem <: System
    to_ignite::Vector{Tuple{Int,Int}}
    to_convert::Vector{Entity}
end
FireSpreadSystem() = FireSpreadSystem(Tuple{Int,Int}[], Entity[])

function update!(system::FireSpreadSystem, world::World)
    grid = get_resource(world, FireGrid)
    stats = get_resource(world, FireStats)

    empty!(system.to_ignite)
    empty!(system.to_convert)

    # Collect all current fires — NetLogo shuffles with `ask fires`
    fire_list = Entity[]
    fire_pos = Tuple{Int,Int}[]
    for (eids, positions, _) in Query(world, (FirePosition, FireTag))
        @inbounds for i in eachindex(positions)
            push!(fire_list, eids[i])
            push!(fire_pos, (positions[i].x, positions[i].y))
        end
    end

    # Shuffle fire processing order (NetLogo `ask` shuffles agentset)
    rng = get_resource(world, RNGResource).rng
    n = length(fire_list)
    for i in n:-1:2
        j = rand(rng, 1:i)
        fire_list[i], fire_list[j] = fire_list[j], fire_list[i]
        fire_pos[i], fire_pos[j] = fire_pos[j], fire_pos[i]
    end

    # Process each fire: spread to green neighbors, then mark for conversion
    # NetLogo default topology is toroidal (wrapping on both axes)
    w, h = grid.width, grid.height
    for k in 1:n
        px, py = fire_pos[k]
        for (dx, dy) in ((0, 1), (0, -1), (1, 0), (-1, 0))
            nx = mod1(px + dx, w)
            ny = mod1(py + dy, h)
            if grid.state[nx, ny] == 1  # tree (green)
                grid.state[nx, ny] = 2  # mark burned immediately to avoid double-ignite
                push!(system.to_ignite, (nx, ny))
                stats.burned_trees += 1
            end
        end
        push!(system.to_convert, fire_list[k])
    end

    # Create new fire entities for ignited patches
    for (x, y) in system.to_ignite
        new_entity!(world, (FirePosition(x, y), FireTag()))
    end

    # Convert fires to embers: remove FireTag, add EmberTag + EmberColor
    for eid in system.to_convert
        is_alive(world, eid) || continue
        exchange_components!(world, eid;
            add = (EmberTag(), EmberColor(15.0)),
            remove = (FireTag,),
        )
    end
    return nothing
end

# --- Ember Fade ---
# NetLogo: ask embers [ set color color - 0.3; if color < red - 3.5 [ set pcolor color; die ] ]

struct EmberFadeSystem <: System
    to_remove::Vector{Entity}
end
EmberFadeSystem() = EmberFadeSystem(Entity[])

function update!(system::EmberFadeSystem, world::World)
    empty!(system.to_remove)

    for (eids, _, _, colors) in Query(world, (FirePosition, EmberTag, EmberColor))
        @inbounds for i in eachindex(colors)
            colors[i].color -= 0.3
            if colors[i].color < 11.5  # red(15.0) - 3.5
                push!(system.to_remove, eids[i])
            end
        end
    end

    for eid in system.to_remove
        is_alive(world, eid) && remove_entity!(world, eid)
    end
    return nothing
end

# --- Termination ---
# NetLogo: if not any? turtles [ stop ]

struct FireTerminationSystem <: System end

function update!(::FireTerminationSystem, world::World)
    params = get_resource(world, FireParams)
    tick = get_resource(world, Tick)

    # Count all fire + ember entities (must fully consume iterator — no break)
    has_active = false
    for (eids, _) in Query(world, (FirePosition,))
        if !isempty(eids)
            has_active = true
        end
    end

    if !has_active || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
