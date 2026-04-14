# DLA model systems matching NetLogo Diffusion-Limited Aggregation
# Execution order: init → update (wiggle + attach) → stats → terminate

# --- Initialization ---
# NetLogo: ask patch 0 0 [ set pcolor green ]
#          create-turtles num-particles [ set color red; set size 1.5; setxy random-xcor random-ycor ]

struct InitDLASystem <: System end

function initialize!(::InitDLASystem, world::World)
    params = get_resource(world, DLAParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, DLAGrid)
    stats = get_resource(world, DLAStats)

    # Seed cluster at center patch: NetLogo patch (0,0) → grid cell (101, 101)
    cx = (params.grid_width + 1) ÷ 2
    cy = (params.grid_height + 1) ÷ 2
    grid.cluster[cx, cy] = true

    # Create particles with random positions and integer headings
    w = Float64(params.grid_width)
    h = Float64(params.grid_height)
    for _ in 1:params.num_particles
        x = rand(rng) * w
        y = rand(rng) * h
        heading = Float64(rand(rng, 0:359))
        new_entity!(world, (DLAPosition(x, y), DLAHeading(heading)))
    end

    stats.n_remaining = params.num_particles
    return nothing
end

# --- DLA Update ---
# NetLogo: ask turtles [ right random wiggle-angle; left random wiggle-angle; fd 1;
#                         if any? neighbors with [pcolor = green] [ set pcolor green; die ] ]
# Turtles processed in shuffled order with immediate grid updates.

struct DLAUpdateSystem <: System
    entity_buf::Vector{Entity}
    to_remove::Vector{Entity}
end
DLAUpdateSystem() = DLAUpdateSystem(Entity[], Entity[])

function update!(system::DLAUpdateSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    params = get_resource(world, DLAParams)
    grid = get_resource(world, DLAGrid)
    gw = params.grid_width
    gh = params.grid_height
    w = Float64(gw)
    h = Float64(gh)
    wa = params.wiggle_angle

    empty!(system.entity_buf)
    empty!(system.to_remove)

    # Collect all particle entities
    for (eids,) in Query(world, (DLAPosition,))
        for i in eachindex(eids)
            push!(system.entity_buf, eids[i])
        end
    end

    # Shuffle for NetLogo-style sequential ask
    shuffle!(rng, system.entity_buf)

    # Process each turtle in shuffled order
    for eid in system.entity_buf
        pos, heading = get_components(world, eid, (DLAPosition, DLAHeading))

        # right random wiggle-angle  (NetLogo random N → integer [0, N-1])
        heading.angle += Float64(rand(rng, 0:(wa - 1)))
        # left random wiggle-angle
        heading.angle -= Float64(rand(rng, 0:(wa - 1)))

        # fd 1 with toroidal wrapping
        θ = deg2rad(heading.angle)
        pos.x = mod(pos.x + sin(θ), w)
        pos.y = mod(pos.y + cos(θ), h)

        # Determine current patch
        gx = clamp(floor(Int, pos.x) + 1, 1, gw)
        gy = clamp(floor(Int, pos.y) + 1, 1, gh)

        # Check 8 Moore neighbors for cluster membership (toroidal)
        attached = false
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = mod1(gx + dx, gw)
            ny = mod1(gy + dy, gh)
            if grid.cluster[nx, ny]
                attached = true
                break
            end
        end

        if attached
            grid.cluster[gx, gy] = true
            push!(system.to_remove, eid)
        end
    end

    # Remove attached particles
    for eid in system.to_remove
        is_alive(world, eid) && remove_entity!(world, eid)
    end

    return nothing
end

# --- Statistics ---
# NetLogo: set n-remaining count turtles

struct DLAStatsSystem <: System end

function update!(::DLAStatsSystem, world::World)
    stats = get_resource(world, DLAStats)
    total = 0
    for (eids,) in Query(world, (DLAPosition,))
        total += length(eids)
    end
    stats.n_remaining = total
    return nothing
end

# --- Termination ---

struct DLATerminationSystem <: System end

function update!(::DLATerminationSystem, world::World)
    params = get_resource(world, DLAParams)
    tick = get_resource(world, Tick)
    stats = get_resource(world, DLAStats)
    if stats.n_remaining == 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
