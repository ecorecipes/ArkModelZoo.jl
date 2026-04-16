function pa_world(; initial_capacity::Int = 1024)
    return World(PANode; initial_capacity = initial_capacity, allow_mutable = true)
end

function pa_systems()
    return (InitPASystem(), PAGoSystem(), PATerminationSystem())
end

function pa_model(params::PAParams = PAParams())
    world = pa_world()
    _add_standard_resources!(world, params)
    add_resource!(world, PANetwork())
    add_resource!(world, PAStats())
    scheduler = Scheduler(world, pa_systems())
    initialize!(scheduler)
    return scheduler
end

struct PAObserver end

function pa_headers(::PAObserver)
    return ["NumNodes", "NumEdges", "MaxDegree"]
end

function pa_values(::PAObserver, world::World)
    stats = get_resource(world, PAStats)
    return Float64[stats.num_nodes, stats.num_edges, stats.max_degree]
end

function run_preferential_attachment(; params::PAParams = PAParams(), observe::Bool = true)
    return _run_model(pa_model, PAObserver(), pa_values; params, observe)
end
