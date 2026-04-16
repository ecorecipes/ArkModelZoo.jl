function termites_world(; initial_capacity::Int = 2048)
    return World(
        TMPosition,
        TMHeading,
        TMCarrying;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function termites_systems()
    return (
        InitTMSystem(),
        TMGoSystem(),
        TMStatsSystem(),
        TMTerminationSystem(),
    )
end

function termites_model(params::TMParams = TMParams())
    world = termites_world()
    _add_standard_resources!(world, params)
    add_resource!(world, TMGrid(params.grid_width, params.grid_height))
    add_resource!(world, TMStats())
    scheduler = Scheduler(world, termites_systems())
    initialize!(scheduler)
    return scheduler
end

struct TMObserver end

function termites_headers(::TMObserver)
    return ["NumChipPatches", "NumCarrying"]
end

function termites_values(::TMObserver, world::World)
    stats = get_resource(world, TMStats)
    return Float64[stats.num_chip_patches, stats.num_carrying]
end

function run_termites(; params::TMParams = TMParams(), observe::Bool = true)
    return _run_model(termites_model, TMObserver(), termites_values; params, observe)
end
