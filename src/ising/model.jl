function ising_world(; initial_capacity::Int = 128)
    return World(
        IsingDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function ising_systems()
    return (
        InitIsingSystem(),
        IsingUpdateSystem(),
        IsingTerminationSystem(),
    )
end

function ising_model(params::IsingParams = IsingParams())
    world = ising_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, IsingGrid(params.grid_width, params.grid_height))
    add_resource!(world, IsingStats())
    scheduler = Scheduler(world, ising_systems())
    initialize!(scheduler)
    return scheduler
end

struct IsingObserver end

function ising_headers(::IsingObserver)
    return ["SumOfSpins"]
end

function ising_values(::IsingObserver, world::World)
    stats = get_resource(world, IsingStats)
    return Float64[stats.sum_of_spins]
end

function run_ising(; params::IsingParams = IsingParams(), observe::Bool = true)
    scheduler = ising_model(params)
    obs = IsingObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, ising_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, ising_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
