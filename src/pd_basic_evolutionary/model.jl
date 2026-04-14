function pde_world(; initial_capacity::Int = 64)
    return World(; initial_capacity = initial_capacity, allow_mutable = true)
end

function pde_systems()
    return (
        InitPDESystem(),
        PDEGoSystem(),
        PDETerminationSystem(),
    )
end

function pde_model(params::PDEParams = PDEParams())
    world = pde_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, PDEGrid(params.grid_width, params.grid_height))
    add_resource!(world, PDEStats())
    scheduler = Scheduler(world, pde_systems())
    initialize!(scheduler)
    return scheduler
end

struct PDEObserver end

function pde_headers(::PDEObserver)
    return ["Cooperators", "Defectors", "CC", "DD"]
end

function pde_values(::PDEObserver, world::World)
    stats = get_resource(world, PDEStats)
    return Float64[stats.num_cooperators, stats.num_defectors,
                    stats.num_cc, stats.num_dd]
end

function run_pd_basic_evolutionary(; params::PDEParams = PDEParams(), observe::Bool = true)
    scheduler = pde_model(params)
    obs = PDEObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, pde_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, pde_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
