function csvnetworkforaging_world(; initial_capacity::Int = 128)
    return World(CNFDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function csvnetworkforaging_systems()
    return (InitCNFSystem(), CNFGoSystem(), CNFTerminationSystem())
end

function csvnetworkforaging_model(params::CNFParams = CNFParams())
    world = csvnetworkforaging_world()
    _add_standard_resources!(world, params)
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
    return _run_model(csvnetworkforaging_model, CNFObserver(), csvnetworkforaging_values; params, observe)
end
