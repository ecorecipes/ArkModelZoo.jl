function rebellion_world(; initial_capacity::Int = 4096)
    return World(REBAgent, REBCop; initial_capacity = initial_capacity, allow_mutable = true)
end

function rebellion_systems()
    return (InitREBSystem(), REBGoSystem(), REBTerminationSystem())
end

function rebellion_model(params::REBParams = REBParams())
    world = rebellion_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = rebellion_model(params)
    obs = REBObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, reb_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, reb_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
