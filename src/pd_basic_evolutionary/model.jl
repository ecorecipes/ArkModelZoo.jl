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
    _add_standard_resources!(world, params)
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
    return _run_model(pde_model, PDEObserver(), pde_values; params, observe)
end
