function heatbugs_world(; initial_capacity::Int = 4096)
    return World(HBPos, HBBug; initial_capacity = initial_capacity, allow_mutable = true)
end

function heatbugs_systems()
    return (InitHBSystem(), HBDiffuseSystem(), HBGoSystem(), HBTerminationSystem())
end

function heatbugs_model(params::HBParams = HBParams())
    world = heatbugs_world()
    _add_standard_resources!(world, params)
    add_resource!(world, HBGrid(params.grid_width, params.grid_height))
    add_resource!(world, HBStats())
    scheduler = Scheduler(world, heatbugs_systems())
    initialize!(scheduler)
    return scheduler
end

struct HBObserver end

function heatbugs_headers(::HBObserver)
    return ["MeanUnhappiness", "MaxUnhappiness"]
end

function heatbugs_values(::HBObserver, world::World)
    stats = get_resource(world, HBStats)
    return Float64[stats.mean_unhappiness, stats.max_unhappiness]
end

function run_heatbugs(; params::HBParams = HBParams(), observe::Bool = true)
    return _run_model(heatbugs_model, HBObserver(), heatbugs_values; params, observe)
end
