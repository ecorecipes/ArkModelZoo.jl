# ── Helper: convert continuous position to grid cell (toroidal) ──

function _tm_to_grid(x::Float64, y::Float64, w::Int, h::Int)
    gx = mod1(round(Int, x), w)
    gy = mod1(round(Int, y), h)
    return gx, gy
end

# NetLogo fd: x += sin(heading°) * dist, y += cos(heading°) * dist
function _tm_fd!(pos::TMPosition, heading::Float64, dist::Float64, w::Int, h::Int)
    θ = heading * π / 180.0
    pos.x += sin(θ) * dist
    pos.y += cos(θ) * dist
    # Wrap toroidally to [1, width] and [1, height]
    half_w = Float64(w) / 2.0
    half_h = Float64(h) / 2.0
    pos.x = mod(pos.x - 0.5, Float64(w)) + 0.5
    pos.y = mod(pos.y - 0.5, Float64(h)) + 0.5
    return nothing
end

# NetLogo wiggle: fd 1; rt random 50; lt random 50
function _tm_wiggle!(pos::TMPosition, heading::TMHeading, rng, w::Int, h::Int)
    _tm_fd!(pos, heading.angle, 1.0, w, h)
    heading.angle = mod(heading.angle + rand(rng, 0:49) - rand(rng, 0:49), 360.0)
    return nothing
end

# ── Initialization ──

struct InitTMSystem <: System end

function initialize!(::InitTMSystem, world::World)
    params = get_resource(world, TMParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, TMGrid)

    # Place chips: each patch has density% chance of a chip
    for x in 1:grid.width, y in 1:grid.height
        if rand(rng) * 100.0 < params.density
            tm_place_chip!(grid, x, y)
        end
    end

    # Create termites at random positions with random headings
    for _ in 1:params.number
        x = rand(rng) * Float64(params.grid_width) + 0.5
        y = rand(rng) * Float64(params.grid_height) + 0.5
        heading = Float64(rand(rng, 0:359))
        new_entity!(world, (
            TMPosition(x, y),
            TMHeading(heading),
            TMCarrying(false),
        ))
    end

    # Compute initial stats
    update!(TMStatsSystem(), world)
    return nothing
end

# ── Go System: each termite does a full cycle per tick ──

struct TMGoSystem <: System
    order::Vector{Int}
end
TMGoSystem() = TMGoSystem(Int[])

function update!(system::TMGoSystem, world::World)
    params = get_resource(world, TMParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, TMGrid)
    w = grid.width
    h = grid.height
    max_steps = params.max_steps

    # Collect all termites into flat arrays
    n = 0
    for (eids, _, _, _) in Query(world, (TMPosition, TMHeading, TMCarrying))
        n += length(eids)
    end
    n == 0 && return nothing

    all_pos = Vector{TMPosition}(undef, n)
    all_head = Vector{TMHeading}(undef, n)
    all_carry = Vector{TMCarrying}(undef, n)

    idx = 0
    for (_, positions, headings, carryings) in Query(world, (TMPosition, TMHeading, TMCarrying))
        @inbounds for i in eachindex(positions)
            idx += 1
            all_pos[idx] = positions[i]
            all_head[idx] = headings[i]
            all_carry[idx] = carryings[i]
        end
    end

    # Shuffle order (NetLogo ask shuffles each tick)
    resize!(system.order, n)
    for i in 1:n
        system.order[i] = i
    end
    Random.shuffle!(rng, system.order)

    for ord_idx in 1:n
        ti = system.order[ord_idx]
        pos = all_pos[ti]
        head = all_head[ti]
        carry = all_carry[ti]

        if carry.carrying
            # Already carrying from previous tick (shouldn't happen in full-cycle model,
            # but handle gracefully): continue find-new-pile → put-down-chip
            _tm_find_new_pile!(pos, head, carry, grid, rng, w, h, max_steps)
            _tm_put_down_chip!(pos, head, carry, grid, rng, w, h, max_steps)
        else
            # Full cycle: search-for-chip → find-new-pile → put-down-chip
            _tm_search_for_chip!(pos, head, carry, grid, rng, w, h, max_steps)
            # Only continue if we picked up a chip
            if carry.carrying
                _tm_find_new_pile!(pos, head, carry, grid, rng, w, h, max_steps)
                _tm_put_down_chip!(pos, head, carry, grid, rng, w, h, max_steps)
            end
        end
    end
    return nothing
end

# search-for-chip: wiggle until on a chip patch, pick it up, fd 20
function _tm_search_for_chip!(pos::TMPosition, head::TMHeading, carry::TMCarrying,
                              grid::TMGrid, rng, w::Int, h::Int, max_steps::Int)
    for _ in 1:max_steps
        gx, gy = _tm_to_grid(pos.x, pos.y, w, h)
        if tm_has_chip(grid, gx, gy)
            # Pick up chip
            tm_remove_chip!(grid, gx, gy)
            carry.carrying = true
            # fd 20 to move away from the pile
            _tm_fd!(pos, head.angle, 20.0, w, h)
            return nothing
        end
        _tm_wiggle!(pos, head, rng, w, h)
    end
    return nothing
end

# find-new-pile: wiggle until on a chip patch (don't pick it up)
function _tm_find_new_pile!(pos::TMPosition, head::TMHeading, carry::TMCarrying,
                            grid::TMGrid, rng, w::Int, h::Int, max_steps::Int)
    for _ in 1:max_steps
        gx, gy = _tm_to_grid(pos.x, pos.y, w, h)
        if tm_has_chip(grid, gx, gy)
            return nothing
        end
        _tm_wiggle!(pos, head, rng, w, h)
    end
    return nothing
end

# put-down-chip: find an empty adjacent spot, drop chip, get-away
function _tm_put_down_chip!(pos::TMPosition, head::TMHeading, carry::TMCarrying,
                            grid::TMGrid, rng, w::Int, h::Int, max_steps::Int)
    for _ in 1:max_steps
        gx, gy = _tm_to_grid(pos.x, pos.y, w, h)
        if !tm_has_chip(grid, gx, gy)
            # Drop chip here
            tm_place_chip!(grid, gx, gy)
            carry.carrying = false
            # get-away: rt random 360, fd 20, repeat until on empty patch
            _tm_get_away!(pos, head, grid, rng, w, h, max_steps)
            return nothing
        end
        # Random turn and step to find empty spot near pile
        head.angle = mod(Float64(rand(rng, 0:359)), 360.0)
        _tm_fd!(pos, head.angle, 1.0, w, h)
    end
    return nothing
end

# get-away: rt random 360, fd 20, repeat until on empty (no chip) patch
function _tm_get_away!(pos::TMPosition, head::TMHeading,
                       grid::TMGrid, rng, w::Int, h::Int, max_steps::Int)
    for _ in 1:max_steps
        head.angle = mod(Float64(rand(rng, 0:359)), 360.0)
        _tm_fd!(pos, head.angle, 20.0, w, h)
        gx, gy = _tm_to_grid(pos.x, pos.y, w, h)
        if !tm_has_chip(grid, gx, gy)
            return nothing
        end
    end
    return nothing
end

# ── Stats System ──

struct TMStatsSystem <: System end

function update!(::TMStatsSystem, world::World)
    grid = get_resource(world, TMGrid)
    stats = get_resource(world, TMStats)

    # Count chip patches on the ground
    chip_count = 0
    for x in 1:grid.width, y in 1:grid.height
        if grid.chips[x, y]
            chip_count += 1
        end
    end
    stats.num_chip_patches = chip_count

    # Count termites carrying chips
    carrying_count = 0
    for (_, carryings) in Query(world, (TMCarrying,))
        @inbounds for i in eachindex(carryings)
            if carryings[i].carrying
                carrying_count += 1
            end
        end
    end
    stats.num_carrying = carrying_count
    return nothing
end

# ── Termination System ──

struct TMTerminationSystem <: System end

function update!(::TMTerminationSystem, world::World)
    params = get_resource(world, TMParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
