function rebellion_world(; initial_capacity::Int = 4096)
    return World(REBAgent, REBCop; initial_capacity = initial_capacity, allow_mutable = true)
end

function rebellion_systems()
    return (InitREBSystem(), REBGoSystem(), REBTerminationSystem())
end

function rebellion_model(params::REBParams = REBParams())
    world = rebellion_world()
    _add_standard_resources!(world, params)
    add_resource!(world, REBGrid(params.grid_width, params.grid_height, params.vision))
    add_resource!(world, REBStats())
    scheduler = Scheduler(world, rebellion_systems())
    initialize!(scheduler)
    return scheduler
end

struct REBObserver end

function reb_headers(::REBObserver)
    return ["Quiet", "Active", "Jailed"]
end

function reb_values(::REBObserver, world::World)
    stats = get_resource(world, REBStats)
    return Float64[stats.num_quiet, stats.num_active, stats.num_jailed]
end

function run_rebellion(; params::REBParams = REBParams(), observe::Bool = true)
    return _run_model(rebellion_model, REBObserver(), reb_values; params, observe)
end
