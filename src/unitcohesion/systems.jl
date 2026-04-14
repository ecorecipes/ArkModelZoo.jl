# --- Initialization ---

struct InitUnitCohesionSystem <: System end

function initialize!(::InitUnitCohesionSystem, world::World)
    params = get_resource(world, UnitCohesionParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, UnitCohesionGrid)
    stats = get_resource(world, UnitCohesionStats)

    w = params.grid_width
    h = params.grid_height

    # ask patches [ sprout 1 [ set age random 156 ] ]
    for x in 1:w, y in 1:h
        grid.age[x, y] = rand(rng, 0:155)
    end
    grid.lifespan = params.initial_lifespan

    total = w * h
    n_turtles = count(>=(0), grid.age)
    stats.n_vacancies = total - n_turtles
    return nothing
end

# --- Aging + Replacement ---

struct UnitCohesionUpdateSystem <: System
    occupied_buf::Vector{Tuple{Int,Int}}
end
UnitCohesionUpdateSystem() = UnitCohesionUpdateSystem(Tuple{Int,Int}[])

function update!(system::UnitCohesionUpdateSystem, world::World)
    params = get_resource(world, UnitCohesionParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, UnitCohesionGrid)
    stats = get_resource(world, UnitCohesionStats)

    w = params.grid_width
    h = params.grid_height
    total = w * h
    ages = grid.age

    # ask turtles [get-older] — random order
    empty!(system.occupied_buf)
    for x in 1:w, y in 1:h
        if ages[x, y] >= 0
            push!(system.occupied_buf, (x, y))
        end
    end
    shuffle!(rng, system.occupied_buf)

    for (x, y) in system.occupied_buf
        ages[x, y] += 1
        if ages[x, y] > grid.lifespan
            ages[x, y] = -1  # die
        end
    end

    # if vacancies > replacement-team-size, fill ALL empty patches
    n_turtles = count(>=(0), ages)
    vacancies = total - n_turtles

    if vacancies > params.replacement_team_size
        for x in 1:w, y in 1:h
            if ages[x, y] < 0
                ages[x, y] = params.replacement_age
            end
        end
        grid.lifespan = params.replacement_lifespan
        n_turtles = total
    end

    stats.n_vacancies = total - n_turtles
    return nothing
end

# --- Termination ---

struct UnitCohesionTerminationSystem <: System end

function update!(::UnitCohesionTerminationSystem, world::World)
    params = get_resource(world, UnitCohesionParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
