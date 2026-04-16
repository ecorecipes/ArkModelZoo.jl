function tumor_world(; initial_capacity::Int = 8192)
    return World(
        TumorPosition,
        TumorHeading,
        TumorAge,
        StemCell,
        MetastaticTag;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function tumor_systems()
    return (
        InitTumorSystem(),
        TumorUpdateSystem(),
        TumorStatsSystem(),
        TumorTerminationSystem(),
    )
end

function tumor_model(params::TumorParams = TumorParams())
    world = tumor_world()
    _add_standard_resources!(world, params)
    add_resource!(world, TumorStats())
    scheduler = Scheduler(world, tumor_systems())
    initialize!(scheduler)
    return scheduler
end

struct TumorObserver end

function tumor_headers(::TumorObserver)
    return ["CellCount"]
end

function tumor_values(::TumorObserver, world::World)
    stats = get_resource(world, TumorStats)
    return Float64[stats.cell_count]
end

function run_tumor(; params::TumorParams = TumorParams(), observe::Bool = true)
    return _run_model(tumor_model, TumorObserver(), tumor_values; params, observe)
end
