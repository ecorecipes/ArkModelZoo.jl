function ca1d_world(; initial_capacity::Int = 64)
    return World(CA1DDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function ca1d_systems()
    return (InitCA1DSystem(), CA1DGoSystem(), CA1DTerminationSystem())
end

function ca1d_model(params::CA1DParams = CA1DParams())
    world = ca1d_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, CA1DGrid(params.grid_width, params.grid_height))
    add_resource!(world, CA1DStats())
    scheduler = Scheduler(world, ca1d_systems())
    initialize!(scheduler)
    return scheduler
end

struct CA1DObserver end

function ca1d_headers(::CA1DObserver)
    return ["CurrentRow", "DensityOn"]
end

function ca1d_values(::CA1DObserver, world::World)
    stats = get_resource(world, CA1DStats)
    return Float64[Float64(stats.current_row), stats.density_on]
end

function run_ca_1d_elementary(; params::CA1DParams = CA1DParams(), observe::Bool = true)
    scheduler = ca1d_model(params)
    obs = CA1DObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, ca1d_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, ca1d_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
