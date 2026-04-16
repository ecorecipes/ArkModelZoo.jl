function boiling_world(; initial_capacity::Int = 128)
    return World(
        BoilingDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function boiling_systems()
    return (
        InitBoilingSystem(),
        BoilingUpdateSystem(),
        BoilingStatsSystem(),
        BoilingTerminationSystem(),
    )
end

function boiling_model(params::BoilingParams = BoilingParams())
    world = boiling_world()
    _add_standard_resources!(world, params)
    add_resource!(world, BoilingGrid(params.grid_width, params.grid_height))
    add_resource!(world, BoilingStats())
    scheduler = Scheduler(world, boiling_systems())
    initialize!(scheduler)
    return scheduler
end

struct BoilingObserver end

function boiling_headers(::BoilingObserver)
    return ["AvgHeat"]
end

function boiling_values(::BoilingObserver, world::World)
    stats = get_resource(world, BoilingStats)
    return Float64[stats.avg_heat]
end

function run_boiling(; params::BoilingParams = BoilingParams(), observe::Bool = true)
    return _run_model(boiling_model, BoilingObserver(), boiling_values; params, observe)
end
