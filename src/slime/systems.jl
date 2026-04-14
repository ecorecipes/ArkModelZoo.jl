# --- Initialization ---

struct InitSLSystem <: System end

function initialize!(::InitSLSystem, world::World)
    params = get_resource(world, SLParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, SLChemicalGrid)

    # Zero chemical grid
    fill!(grid.chemical, 0.0)

    # Create turtles at random positions with random headings
    w, h = grid.width, grid.height
    for _ in 1:params.population
        x = rand(rng) * w + 0.5   # continuous position in [0.5, w+0.5)
        y = rand(rng) * h + 0.5
        heading = rand(rng) * 360.0
        new_entity!(world, (
            SLPosition(x, y),
            SLHeading(heading),
        ))
    end

    return nothing
end

# --- Helper: patch coordinates from continuous position ---

@inline function _sl_patch(x::Float64, y::Float64, w::Int, h::Int)
    return mod1(round(Int, x), w), mod1(round(Int, y), h)
end

# Helper: patch at a given heading and distance from continuous position
@inline function _sl_patch_ahead(x::Float64, y::Float64, heading::Float64,
                                  dist::Float64, w::Int, h::Int)
    θ = deg2rad(heading)
    nx = x + sin(θ) * dist
    ny = y + cos(θ) * dist
    return mod1(round(Int, nx), w), mod1(round(Int, ny), h)
end

# --- Go System ---

struct SLGoSystem <: System end

function update!(::SLGoSystem, world::World)
    params = get_resource(world, SLParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, SLChemicalGrid)
    stats = get_resource(world, SLStats)
    w, h = grid.width, grid.height
    chem = grid.chemical

    # Collect all turtle entities for shuffled ask ordering
    turtle_data = Tuple{Entity, Int}[]
    for (eids, _, _) in Query(world, (SLPosition, SLHeading))
        for i in eachindex(eids)
            push!(turtle_data, (eids[i], i))
        end
    end
    Random.shuffle!(rng, turtle_data)

    # Ask turtles (shuffled)
    for (eid, _) in turtle_data
        pos, hdg = get_components(world, eid, (SLPosition, SLHeading))

        # 1. Sniff and turn toward chemical if above threshold
        gx, gy = _sl_patch(pos.x, pos.y, w, h)
        if chem[gx, gy] > params.sniff_threshold
            _sl_turn_toward_chemical!(pos, hdg, chem, params.sniff_angle, w, h)
        end

        # 2. Wiggle: rt random-float wiggle_angle - random-float wiggle_angle + wiggle_bias
        wiggle = rand(rng) * params.wiggle_angle - rand(rng) * params.wiggle_angle + params.wiggle_bias
        hdg.heading = mod(hdg.heading + wiggle, 360.0)

        # 3. Forward 1
        θ = deg2rad(hdg.heading)
        pos.x += sin(θ)
        pos.y += cos(θ)
        # Toroidal wrapping (continuous)
        pos.x = mod(pos.x - 0.5, Float64(w)) + 0.5
        pos.y = mod(pos.y - 0.5, Float64(h)) + 0.5

        # 4. Deposit chemical on current patch
        gx, gy = _sl_patch(pos.x, pos.y, w, h)
        chem[gx, gy] += params.deposit_amount
    end

    # Diffuse chemical
    _sl_diffuse!(chem, params.diffusion_rate, w, h)

    # Evaporate
    @inbounds for i in eachindex(chem)
        chem[i] *= params.evaporation_rate
    end

    # Update stats
    total = 0.0
    mx = 0.0
    @inbounds for i in eachindex(chem)
        v = chem[i]
        total += v
        if v > mx
            mx = v
        end
    end
    stats.total_chemical = total
    stats.max_chemical = mx

    return nothing
end

# NetLogo turn-toward-chemical
function _sl_turn_toward_chemical!(pos::SLPosition, hdg::SLHeading,
                                    chem::Matrix{Float64},
                                    sniff_angle::Float64, w::Int, h::Int)
    ahead_x, ahead_y = _sl_patch_ahead(pos.x, pos.y, hdg.heading, 1.0, w, h)
    right_x, right_y = _sl_patch_ahead(pos.x, pos.y, hdg.heading + sniff_angle, 1.0, w, h)
    left_x, left_y = _sl_patch_ahead(pos.x, pos.y, hdg.heading - sniff_angle, 1.0, w, h)

    ahead_chem = chem[ahead_x, ahead_y]
    right_chem = chem[right_x, right_y]
    left_chem = chem[left_x, left_y]

    if right_chem >= ahead_chem && right_chem >= left_chem
        hdg.heading = mod(hdg.heading + sniff_angle, 360.0)
    elseif left_chem >= ahead_chem
        hdg.heading = mod(hdg.heading - sniff_angle + 360.0, 360.0)
    end
    return nothing
end

# NetLogo `diffuse chemical fraction`:
# Each patch shares `fraction` of its value equally to 8 neighbors (1/8 each).
# Patch keeps (1 - fraction) of its original value plus what it receives from neighbors.
function _sl_diffuse!(chem::Matrix{Float64}, fraction::Float64, w::Int, h::Int)
    old = copy(chem)
    share = fraction / 8.0
    keep = 1.0 - fraction

    @inbounds for x in 1:w, y in 1:h
        val = old[x, y]
        chem[x, y] = keep * val
    end

    @inbounds for x in 1:w, y in 1:h
        contribution = old[x, y] * share
        contribution == 0.0 && continue
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = mod1(x + dx, w)
            ny = mod1(y + dy, h)
            chem[nx, ny] += contribution
        end
    end
    return nothing
end

# --- Termination ---

struct SLTerminationSystem <: System end

function update!(::SLTerminationSystem, world::World)
    params = get_resource(world, SLParams)
    tick = get_resource(world, Tick)

    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
