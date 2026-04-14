function pdsimple_world(; initial_capacity::Int = 128)
    return World(PDSDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function pdsimple_systems()
    return (
        InitPDSSystem(),
        PDSPlayGameSystem(),
        PDSEvolveSystem(),
        PDSTerminationSystem(),
    )
end

function pdsimple_model(params::PDSimpleParams = PDSimpleParams())
    world = pdsimple_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, PDSGrid(params.grid_size, params.grid_size))
    add_resource!(world, PDSStats())
    scheduler = Scheduler(world, pdsimple_systems())
    initialize!(scheduler)
    return scheduler
end

struct PDSimpleObserver end

function pdsimple_headers(::PDSimpleObserver)
    return ["NCooperators"]
end

function pdsimple_values(::PDSimpleObserver, world::World)
    stats = get_resource(world, PDSStats)
    return Float64[stats.n_cooperators]
end

function run_pdsimple(; params::PDSimpleParams = PDSimpleParams(), observe::Bool = true)
    scheduler = pdsimple_model(params)
    obs = PDSimpleObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, pdsimple_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, pdsimple_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
