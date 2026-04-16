function life_world(; initial_capacity::Int = 128)
    return World(LFDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function life_systems()
    return (
        InitLFSystem(),
        LFGoSystem(),
        LFTerminationSystem(),
    )
end

function life_model(params::LFParams = LFParams())
    world = life_world()
    _add_standard_resources!(world, params)
    add_resource!(world, LFGrid(params.grid_width, params.grid_height))
    add_resource!(world, LFStats())
    scheduler = Scheduler(world, life_systems())
    initialize!(scheduler)
    return scheduler
end

struct LFObserver end

function life_headers(::LFObserver)
    return ["LivingCount", "Density"]
end

function life_values(::LFObserver, world::World)
    stats = get_resource(world, LFStats)
    return Float64[stats.living_count, stats.density]
end

function run_life(; params::LFParams = LFParams(), observe::Bool = true)
    return _run_model(life_model, LFObserver(), life_values; params, observe)
end
