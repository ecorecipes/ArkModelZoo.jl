function rgw_world(; initial_capacity::Int = 4096)
    return World(
        RGWPosition,
        RGWHeading,
        RGWEnergy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function rgw_systems()
    return (
        InitRGWSystem(),
        RGWGoSystem(),
        RGWTerminationSystem(),
    )
end

function rgw_model(params::RGWParams = RGWParams())
    world = rgw_world()
    _add_standard_resources!(world, params)
    add_resource!(world, RGWPatchGrid(params.grid_width, params.grid_height))
    add_resource!(world, RGWStats())
    scheduler = Scheduler(world, rgw_systems())
    initialize!(scheduler)
    return scheduler
end

struct RGWObserver end

function rgw_headers(::RGWObserver)
    return ["Rabbits", "Grass", "Weeds"]
end

function rgw_values(::RGWObserver, world::World)
    stats = get_resource(world, RGWStats)
    return Float64[stats.num_rabbits, stats.num_grass, stats.num_weeds]
end

function run_rgw(; params::RGWParams = RGWParams(), observe::Bool = true)
    return _run_model(rgw_model, RGWObserver(), rgw_values; params, observe)
end
