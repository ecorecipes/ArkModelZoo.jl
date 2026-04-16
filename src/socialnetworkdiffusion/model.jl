function socialnetworkdiffusion_world(; initial_capacity::Int = 128)
    return World(SNDDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function socialnetworkdiffusion_systems()
    return (InitSNDSystem(), SNDGoSystem(), SNDTerminationSystem())
end

function socialnetworkdiffusion_model(params::SocialNetDiffParams = SocialNetDiffParams())
    world = socialnetworkdiffusion_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SNDNetwork())
    add_resource!(world, SNDStats())
    scheduler = Scheduler(world, socialnetworkdiffusion_systems())
    initialize!(scheduler)
    return scheduler
end

struct SNDObserver end

function socialnetworkdiffusion_headers(::SNDObserver)
    return ["NumRed", "NumGrey", "AvgUtility"]
end

function socialnetworkdiffusion_values(::SNDObserver, world::World)
    stats = get_resource(world, SNDStats)
    return Float64[stats.num_red, stats.num_grey, stats.avg_utility]
end

function run_socialnetworkdiffusion(; params::SocialNetDiffParams = SocialNetDiffParams(), observe::Bool = true)
    return _run_model(socialnetworkdiffusion_model, SNDObserver(), socialnetworkdiffusion_values; params, observe)
end
