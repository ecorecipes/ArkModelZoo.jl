function heatbugs_world(; initial_capacity::Int = 4096)
    return World(HBPos, HBBug; initial_capacity = initial_capacity, allow_mutable = true)
end

function heatbugs_systems()
    return (InitHBSystem(), HBDiffuseSystem(), HBGoSystem(), HBTerminationSystem())
end

function heatbugs_model(params::HBParams = HBParams())
    world = heatbugs_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = heatbugs_model(params)
    obs = HBObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, heatbugs_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, heatbugs_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
