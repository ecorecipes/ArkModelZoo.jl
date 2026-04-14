const THERMO_INTERIOR = Int8(0)
const THERMO_WALL     = Int8(1)
const THERMO_GREEN    = Int8(2)

# --- Grid helpers ---

# Convert continuous position to patch coordinate (NetLogo round-to-nearest)
_thermo_patch(v::Float64) = round(Int, v)

# Convert patch coordinate to 1-based grid index
_thermo_idx(pc::Int, min_cor::Int) = pc - min_cor + 1

# Check if patch (px,py) is inside the grid
function _thermo_in_bounds(px::Int, py::Int, min_cor::Int, max_cor::Int)
    return min_cor <= px <= max_cor && min_cor <= py <= max_cor
end

# Get patch type at continuous position
function _thermo_ptype(grid::ThermoGrid, x::Float64, y::Float64)
    px = _thermo_patch(x)
    py = _thermo_patch(y)
    if !_thermo_in_bounds(px, py, grid.min_cor, grid.min_cor + grid.width - 1)
        return THERMO_WALL  # out of bounds treated as wall
    end
    ix = _thermo_idx(px, grid.min_cor)
    iy = _thermo_idx(py, grid.min_cor)
    return grid.cells[ix, iy]
end

# --- Initialization ---

struct InitThermoSystem <: System end

function initialize!(::InitThermoSystem, world::World)
    params = get_resource(world, ThermostatParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, ThermoGrid)
    stats = get_resource(world, ThermoStats)

    min_c = params.min_cor
    max_c = params.max_cor

    # Wall boundary at ±(max_cor - 7) = ±28
    wall_bound = max_c - 7  # 28

    # Set up grid patch types
    for px in min_c:max_c, py in min_c:max_c
        ix = _thermo_idx(px, min_c)
        iy = _thermo_idx(py, min_c)
        if abs(px) >= wall_bound || abs(py) >= wall_bound
            grid.cells[ix, iy] = THERMO_WALL
        elseif abs(px) < 5 && py > (max_c - 25) && py < (max_c - 15)
            # Thermometer: |x|<5 and 10<y<20 → py in 11..19
            grid.cells[ix, iy] = THERMO_GREEN
        else
            grid.cells[ix, iy] = THERMO_INTERIOR
        end
    end

    # Initial temperature readings
    stats.temperatures = fill(Float64(params.initial_temp), 10)
    stats.temperature = Float64(params.initial_temp)

    # Create initial heat particles at origin with random heading, fd random-float 27
    w = params.grid_width
    move_dist_max = Float64(max_c - 8)  # 27.0
    n_initial = round(Int, params.initial_temp * ((w - 16)^2 / 81.0))

    for _ in 1:n_initial
        heading = Float64(rand(rng, 0:359))
        dist = rand(rng) * move_dist_max
        θ = deg2rad(heading)
        x = sin(θ) * dist
        y = cos(θ) * dist
        new_entity!(world, (ThermoPosition(x, y), ThermoHeading(heading)))
    end
    return nothing
end

# --- Circulation ---
# NetLogo: if pcolor=yellow and random-float insulation > 1 → redirect.
# Then fd 1. If not can-move? 1 → die.

mutable struct ThermoCirculateSystem <: System
    to_remove::Vector{Entity}
end
ThermoCirculateSystem() = ThermoCirculateSystem(Entity[])

function update!(system::ThermoCirculateSystem, world::World)
    params = get_resource(world, ThermostatParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, ThermoGrid)
    min_c = params.min_cor
    max_c = params.max_cor
    w = params.grid_width
    half_world = Float64(max_c) + 0.5  # 35.5

    # facexy target ranges
    face_xrange = Float64(w - 13)   # 58.0
    face_yrange = Float64(w - 14)   # 57.0
    face_offset = Float64(max_c - 6) # 29.0

    empty!(system.to_remove)

    for (eids, positions, headings) in Query(world, (ThermoPosition, ThermoHeading))
        @inbounds for i in eachindex(positions)
            x = positions[i].x
            y = positions[i].y
            ptype = _thermo_ptype(grid, x, y)

            # On wall patch: chance to redirect toward interior
            if ptype == THERMO_WALL
                if rand(rng) * params.insulation > 1.0
                    # facexy random interior point
                    tx = rand(rng) * face_xrange - face_offset
                    ty = rand(rng) * face_yrange - face_offset
                    dx = tx - x
                    dy = ty - y
                    headings[i].angle = atand(dx, dy)  # NetLogo heading convention
                end
            end

            # fd 1
            θ = deg2rad(headings[i].angle)
            nx = x + sin(θ)
            ny = y + cos(θ)
            positions[i].x = nx
            positions[i].y = ny

            # can-move? 1 check: would next step go out of world?
            check_x = nx + sin(θ)
            check_y = ny + cos(θ)
            if check_x < -half_world || check_x > half_world ||
               check_y < -half_world || check_y > half_world
                push!(system.to_remove, eids[i])
            end
        end
    end

    for e in system.to_remove
        is_alive(world, e) && remove_entity!(world, e)
    end
    return nothing
end

# --- Temperature measurement ---

struct ThermoTemperatureSystem <: System end

function update!(::ThermoTemperatureSystem, world::World)
    grid = get_resource(world, ThermoGrid)
    stats = get_resource(world, ThermoStats)

    # Count particles on green (thermometer) patches
    count_green = 0
    for (_, positions) in Query(world, (ThermoPosition,))
        @inbounds for i in eachindex(positions)
            if _thermo_ptype(grid, positions[i].x, positions[i].y) == THERMO_GREEN
                count_green += 1
            end
        end
    end

    # Update rolling temperature: but-last fput count temperatures
    pop!(stats.temperatures)
    pushfirst!(stats.temperatures, Float64(count_green))
    stats.temperature = sum(stats.temperatures) / length(stats.temperatures)
    return nothing
end

# --- Heater control ---

struct ThermoHeaterSystem <: System end

function update!(::ThermoHeaterSystem, world::World)
    params = get_resource(world, ThermostatParams)
    rng = get_resource(world, RNGResource).rng
    stats = get_resource(world, ThermoStats)

    if stats.temperature < params.goal_temp
        # Create heater_strength new particles at origin with random heading
        for _ in 1:params.heater_strength
            heading = Float64(rand(rng, 0:359))
            new_entity!(world, (ThermoPosition(0.0, 0.0), ThermoHeading(heading)))
        end
    end
    return nothing
end

# --- Stats (temperature already computed) ---

struct ThermoStatsSystem <: System end
function update!(::ThermoStatsSystem, world::World)
    return nothing
end

# --- Termination ---

struct ThermoTerminationSystem <: System end

function update!(::ThermoTerminationSystem, world::World)
    params = get_resource(world, ThermostatParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
