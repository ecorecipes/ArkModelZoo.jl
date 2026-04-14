function riseofradicalism_world(; initial_capacity::Int = 128)
    return World(
        RadDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function riseofradicalism_systems()
    return (
        InitRadSystem(),
        RadBorderSystem(),
        RadSlopeSystem(),
        RadSpreadSystem(),
        RadNetworkSystem(),
        RadTownshipSystem(),
        RadStatsSystem(),
        RadTerminationSystem(),
    )
end

function riseofradicalism_model(params::RadParams = RadParams())
    world = riseofradicalism_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, RadGrid(params.grid_width, params.grid_height))
    add_resource!(world, RadState())
    add_resource!(world, RadStats())
    scheduler = Scheduler(world, riseofradicalism_systems())
    initialize!(scheduler)
    return scheduler
end

struct RadObserver end

function riseofradicalism_headers(::RadObserver)
    return ["PercentRadicals", "OvertakenTownships", "TotalRadicalism"]
end

function riseofradicalism_values(::RadObserver, world::World)
    stats = get_resource(world, RadStats)
    return Float64[stats.percent_radicals, stats.overtaken_townships, stats.total_radicalism]
end

function run_riseofradicalism(; params::RadParams = RadParams(), observe::Bool = true)
    scheduler = riseofradicalism_model(params)
    obs = RadObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, riseofradicalism_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, riseofradicalism_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
