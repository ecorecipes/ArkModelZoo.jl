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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = tumor_model(params)
    obs = TumorObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, tumor_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, tumor_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
