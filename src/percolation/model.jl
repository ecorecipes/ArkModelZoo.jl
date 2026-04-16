function percolation_world(; initial_capacity::Int = 64)
    return World(PERCDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function percolation_systems()
    return (InitPERCSystem(), PERCGoSystem(), PERCTerminationSystem())
end

function percolation_model(params::PERCParams = PERCParams())
    world = percolation_world()
    _add_standard_resources!(world, params)
    add_resource!(world, PERCGrid(params.grid_width, params.grid_height))
    add_resource!(world, PERCStats())
    scheduler = Scheduler(world, percolation_systems())
    initialize!(scheduler)
    return scheduler
end

struct PERCObserver end

function percolation_headers(::PERCObserver)
    return ["LeadingEdgeCount", "TotalOil"]
end

function percolation_values(::PERCObserver, world::World)
    stats = get_resource(world, PERCStats)
    return Float64[Float64(stats.leading_edge_count), Float64(stats.total_oil)]
end

function run_percolation(; params::PERCParams = PERCParams(), observe::Bool = true)
    return _run_model(percolation_model, PERCObserver(), percolation_values; params, observe)
end
