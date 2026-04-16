function gishillclimber_world(; initial_capacity::Int = 256)
    return World(
        GHCPosition,
        GHCTag;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function gishillclimber_systems()
    return (
        InitGHCSystem(),
        GHCMoveSystem(),
        GHCStatsSystem(),
        GHCTerminationSystem(),
    )
end

function gishillclimber_model(params::GHCParams = GHCParams())
    world = gishillclimber_world()
    _add_standard_resources!(world, params)
    add_resource!(world, GHCGrid(params.grid_size, params.grid_size))
    add_resource!(world, GHCStats())
    scheduler = Scheduler(world, gishillclimber_systems())
    initialize!(scheduler)
    return scheduler
end

struct GHCObserver end

function gishillclimber_headers(::GHCObserver)
    return ["MeanElevation", "NAtPeak"]
end

function gishillclimber_values(::GHCObserver, world::World)
    stats = get_resource(world, GHCStats)
    return Float64[stats.mean_elevation, Float64(stats.n_at_peak)]
end

function run_gishillclimber(; params::GHCParams = GHCParams(), observe::Bool = true)
    return _run_model(gishillclimber_model, GHCObserver(), gishillclimber_values; params, observe)
end
