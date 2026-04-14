function csvnetworkforaging_world(; initial_capacity::Int = 128)
    return World(CNFDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function csvnetworkforaging_systems()
    return (InitCNFSystem(), CNFGoSystem(), CNFTerminationSystem())
end

function csvnetworkforaging_model(params::CNFParams = CNFParams())
    world = csvnetworkforaging_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, CNFNetwork())
    add_resource!(world, CNFStats())
    scheduler = Scheduler(world, csvnetworkforaging_systems())
    initialize!(scheduler)
    return scheduler
end

struct CNFObserver end

function csvnetworkforaging_headers(::CNFObserver)
    return ["total-supply", "num-consumers", "total-consumed"]
end

function csvnetworkforaging_values(::CNFObserver, world::World)
    stats = get_resource(world, CNFStats)
    return Float64[stats.total_supply, stats.num_consumers, stats.total_consumed]
end

function run_csvnetworkforaging(; params::CNFParams = CNFParams(), observe::Bool = true)
    scheduler = csvnetworkforaging_model(params)
    obs = CNFObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, csvnetworkforaging_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, csvnetworkforaging_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
