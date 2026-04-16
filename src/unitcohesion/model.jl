function unitcohesion_world(; initial_capacity::Int = 128)
    return World(
        UnitCohesionDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function unitcohesion_systems()
    return (
        InitUnitCohesionSystem(),
        UnitCohesionUpdateSystem(),
        UnitCohesionTerminationSystem(),
    )
end

function unitcohesion_model(params::UnitCohesionParams = UnitCohesionParams())
    world = unitcohesion_world()
    _add_standard_resources!(world, params)
    add_resource!(world, UnitCohesionGrid(params.grid_width, params.grid_height, params.initial_lifespan))
    add_resource!(world, UnitCohesionStats())
    scheduler = Scheduler(world, unitcohesion_systems())
    initialize!(scheduler)
    return scheduler
end

struct UnitCohesionObserver end

function unitcohesion_headers(::UnitCohesionObserver)
    return ["NVacancies"]
end

function unitcohesion_values(::UnitCohesionObserver, world::World)
    stats = get_resource(world, UnitCohesionStats)
    return Float64[stats.n_vacancies]
end

function run_unitcohesion(; params::UnitCohesionParams = UnitCohesionParams(), observe::Bool = true)
    return _run_model(unitcohesion_model, UnitCohesionObserver(), unitcohesion_values; params, observe)
end
