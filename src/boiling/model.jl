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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = boiling_model(params)
    obs = BoilingObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, boiling_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, boiling_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
