function diffusionofhiv_world(; initial_capacity::Int = 128)
    return World(
        HIVDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function diffusionofhiv_systems()
    return (
        InitHIVSystem(),
        HIVAgingSystem(),
        HIVMovementSystem(),
        HIVCouplingSystem(),
        HIVReturnSystem(),
        HIVStatsSystem(),
        HIVTerminationSystem(),
    )
end

function diffusionofhiv_model(params::HIVParams = HIVParams())
    world = diffusionofhiv_world()
    _add_standard_resources!(world, params)
    add_resource!(world, HIVState(params.grid_width, params.grid_height))
    add_resource!(world, HIVStats())
    scheduler = Scheduler(world, diffusionofhiv_systems())
    initialize!(scheduler)
    return scheduler
end

struct HIVObserver end

function diffusionofhiv_headers(::HIVObserver)
    return ["PctInfected"]
end

function diffusionofhiv_values(::HIVObserver, world::World)
    stats = get_resource(world, HIVStats)
    return Float64[stats.pct_infected]
end

function run_diffusionofhiv(; params::HIVParams = HIVParams(), observe::Bool = true)
    return _run_model(diffusionofhiv_model, HIVObserver(), diffusionofhiv_values; params, observe)
end
