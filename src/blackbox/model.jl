function blackbox_world(; initial_capacity::Int = 128)
    return World(BBoxDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function blackbox_systems()
    return (InitBBoxSystem(), BBoxGoSystem(), BBoxTerminationSystem())
end

function blackbox_model(params::BBoxParams = BBoxParams())
    world = blackbox_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, BBoxGrid(params.grid_size, params.grid_size))
    add_resource!(world, BBoxStats())
    scheduler = Scheduler(world, blackbox_systems())
    initialize!(scheduler)
    return scheduler
end

struct BBoxObserver end

function blackbox_headers(::BBoxObserver)
    return ["Q4t", "Q3t"]
end

function blackbox_values(::BBoxObserver, world::World)
    stats = get_resource(world, BBoxStats)
    return Float64[stats.q4t, stats.q3t]
end

function run_blackbox(; params::BBoxParams = BBoxParams(), observe::Bool = true)
    scheduler = blackbox_model(params)
    obs = BBoxObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, blackbox_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, blackbox_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
