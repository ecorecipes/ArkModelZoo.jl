# DLA Simple — diffusion-limited aggregation with death
# 201×201 wrapping grid, center seed, 2500 red turtles wiggle+attach+die

struct InitDLAsSystem <: System end

function initialize!(::InitDLAsSystem, world::World)
    params = get_resource(world, DLAsParams)
    rng    = get_resource(world, RNGResource).rng
    grid   = get_resource(world, DLAsGrid)
    stats  = get_resource(world, DLAsStats)

    # Seed cluster at center
    cx = (params.grid_width + 1) ÷ 2
    cy = (params.grid_height + 1) ÷ 2
    grid.cluster[cx, cy] = true

    w = Float64(params.grid_width)
    h = Float64(params.grid_height)
    for _ in 1:params.num_particles
        x = rand(rng) * w
        y = rand(rng) * h
        heading = Float64(rand(rng, 0:359))
        new_entity!(world, (DLAsPosition(x, y), DLAsHeading(heading)))
    end
    stats.n_remaining = params.num_particles
    return nothing
end

# --- Update: wiggle, move, attach ---
struct DLAsUpdateSystem <: System
    entity_buf::Vector{Entity}
    to_remove::Vector{Entity}
end
DLAsUpdateSystem() = DLAsUpdateSystem(Entity[], Entity[])

function update!(sys::DLAsUpdateSystem, world::World)
    rng    = get_resource(world, RNGResource).rng
    params = get_resource(world, DLAsParams)
    grid   = get_resource(world, DLAsGrid)
    gw = params.grid_width
    gh = params.grid_height
    w  = Float64(gw)
    h  = Float64(gh)
    wa = params.wiggle_angle

    empty!(sys.entity_buf)
    empty!(sys.to_remove)

    for (eids,) in Query(world, (DLAsPosition,))
        for i in eachindex(eids)
            push!(sys.entity_buf, eids[i])
        end
    end
    shuffle!(rng, sys.entity_buf)

    for eid in sys.entity_buf
        is_alive(world, eid) || continue
        pos, heading = get_components(world, eid, (DLAsPosition, DLAsHeading))

        # Wiggle: right random wiggle-angle, left random wiggle-angle
        heading.angle += Float64(rand(rng, 0:(wa - 1)))
        heading.angle -= Float64(rand(rng, 0:(wa - 1)))

        # Forward 1 (NetLogo heading: 0=north, clockwise)
        θ = deg2rad(heading.angle)
        pos.x = mod(pos.x + sin(θ), w)
        pos.y = mod(pos.y + cos(θ), h)

        # Current patch
        gx = clamp(floor(Int, pos.x) + 1, 1, gw)
        gy = clamp(floor(Int, pos.y) + 1, 1, gh)

        # Check 8 Moore neighbors for green (cluster)
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
            push!(sys.to_remove, eid)
        end
    end

    for eid in sys.to_remove
        is_alive(world, eid) && remove_entity!(world, eid)
    end
    return nothing
end

# --- Stats ---
struct DLAsStatsSystem <: System end

function update!(::DLAsStatsSystem, world::World)
    stats = get_resource(world, DLAsStats)
    total = 0
    for (eids,) in Query(world, (DLAsPosition,))
        total += length(eids)
    end
    stats.n_remaining = total
    return nothing
end

# --- Termination ---
struct DLAsTerminationSystem <: System end

function update!(::DLAsTerminationSystem, world::World)
    params = get_resource(world, DLAsParams)
    tick   = get_resource(world, Tick)
    stats  = get_resource(world, DLAsStats)
    if stats.n_remaining == 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
