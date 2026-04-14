# ── Helper: NetLogo heading math and toroidal distance ──

function _particles_heading_to_rad(h::Float64)
    return h * π / 180.0
end

function _particles_torus_dist(x1::Float64, y1::Float64, x2::Float64, y2::Float64, w::Float64, h::Float64)
    dx = abs(x1 - x2)
    dy = abs(y1 - y2)
    dx = min(dx, w - dx)
    dy = min(dy, h - dy)
    return sqrt(dx * dx + dy * dy)
end

# ── Initialization ──

struct InitParticlesSystem <: System end

function initialize!(::InitParticlesSystem, world::World)
    params = get_resource(world, ParticlesParams)
    rng = get_resource(world, RNGResource).rng
    w = Float64(params.grid_width)
    h = Float64(params.grid_height)
    half_w = w / 2.0
    half_h = h / 2.0

    for _ in 1:params.num_particles
        # random-xcor/ycor: float in [-half_w, half_w)
        x = rand(rng) * w - half_w
        y = rand(rng) * h - half_h
        # heading random 360: integer [0, 359]
        heading = Float64(rand(rng, 0:359))
        new_entity!(world, (
            ParticlePosition(x, y),
            ParticleHeading(heading),
        ))
    end
    return nothing
end

# ── Particle Movement + Collision System ──
# NetLogo: ask turtles [ fd speed; if count in-radius 1 > 1 [
#   ask turtles in-radius 1 [ set heading random 360; fd 0.1 ]
#   set collisions collisions + 1 ] ]
# Sequential (shuffled) processing; mutations visible to later iterations.

struct ParticleSystem <: System
    order::Vector{Int}
    nearby::Vector{Int}
end
ParticleSystem() = ParticleSystem(Int[], Int[])

function update!(system::ParticleSystem, world::World)
    params = get_resource(world, ParticlesParams)
    stats = get_resource(world, ParticleStats)
    rng = get_resource(world, RNGResource).rng
    w = Float64(params.grid_width)
    h = Float64(params.grid_height)
    half_w = w / 2.0
    half_h = h / 2.0
    speed = params.speed
    coll_radius = params.collision_radius
    coll_speed = params.collision_speed

    # Collect entities into flat arrays
    n = 0
    for (eids, _, _) in Query(world, (ParticlePosition, ParticleHeading))
        n += length(eids)
    end
    n == 0 && return nothing

    pos_x = Vector{Float64}(undef, n)
    pos_y = Vector{Float64}(undef, n)
    headings = Vector{Float64}(undef, n)

    idx = 0
    for (_, positions, heads) in Query(world, (ParticlePosition, ParticleHeading))
        @inbounds for i in eachindex(positions)
            idx += 1
            pos_x[idx] = positions[i].x
            pos_y[idx] = positions[i].y
            headings[idx] = heads[i].angle
        end
    end

    # Shuffle order (NetLogo ask turtles shuffles)
    resize!(system.order, n)
    for i in 1:n
        system.order[i] = i
    end
    for i in n:-1:2
        j = rand(rng, 1:i)
        system.order[i], system.order[j] = system.order[j], system.order[i]
    end

    for ord_idx in 1:n
        ti = system.order[ord_idx]

        # forward speed
        θ = _particles_heading_to_rad(headings[ti])
        pos_x[ti] += sin(θ) * speed
        pos_y[ti] += cos(θ) * speed
        pos_x[ti] = mod(pos_x[ti] + half_w, w) - half_w
        pos_y[ti] = mod(pos_y[ti] + half_h, h) - half_h

        # count turtles in-radius 1 (includes self)
        empty!(system.nearby)
        for j in 1:n
            d = _particles_torus_dist(pos_x[ti], pos_y[ti], pos_x[j], pos_y[j], w, h)
            if d <= coll_radius
                push!(system.nearby, j)
            end
        end

        # if count > 1, at least one other turtle nearby
        if length(system.nearby) > 1
            # Inner ask shuffles too
            for i in length(system.nearby):-1:2
                j = rand(rng, 1:i)
                system.nearby[i], system.nearby[j] = system.nearby[j], system.nearby[i]
            end
            for nj in system.nearby
                headings[nj] = Float64(rand(rng, 0:359))
                θ2 = _particles_heading_to_rad(headings[nj])
                pos_x[nj] += sin(θ2) * coll_speed
                pos_y[nj] += cos(θ2) * coll_speed
                pos_x[nj] = mod(pos_x[nj] + half_w, w) - half_w
                pos_y[nj] = mod(pos_y[nj] + half_h, h) - half_h
            end
            stats.collisions += 1
        end
    end

    # Write positions and headings back to world
    idx = 0
    for (_, positions, heads) in Query(world, (ParticlePosition, ParticleHeading))
        @inbounds for i in eachindex(positions)
            idx += 1
            positions[i].x = pos_x[idx]
            positions[i].y = pos_y[idx]
            heads[i].angle = headings[idx]
        end
    end
    return nothing
end

# ── Termination System ──

struct ParticlesTerminationSystem <: System end

function update!(::ParticlesTerminationSystem, world::World)
    params = get_resource(world, ParticlesParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
