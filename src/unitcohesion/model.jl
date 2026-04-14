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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = unitcohesion_model(params)
    obs = UnitCohesionObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, unitcohesion_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, unitcohesion_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
