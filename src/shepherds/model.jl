function shepherds_world(; initial_capacity::Int = 4096)
    return World(SHSheepPos, SHShepherdState; initial_capacity = initial_capacity, allow_mutable = true)
end

function shepherds_systems()
    return (InitSHSystem(), SHGoSystem(), SHStatsSystem(), SHTerminationSystem())
end

function shepherds_model(params::SHParams = SHParams())
    world = shepherds_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, SHGrid(params.grid_width, params.grid_height))
    add_resource!(world, SHStats())
    scheduler = Scheduler(world, shepherds_systems())
    initialize!(scheduler)
    return scheduler
end

struct SHObserver end

function shepherds_headers(::SHObserver)
    return ["HerdingEfficiency", "NumSheepVisible"]
end

function shepherds_values(::SHObserver, world::World)
    stats = get_resource(world, SHStats)
    return Float64[stats.herding_efficiency, Float64(stats.num_sheep_visible)]
end

function run_shepherds(; params::SHParams = SHParams(), observe::Bool = true)
    scheduler = shepherds_model(params)
    obs = SHObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, shepherds_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, shepherds_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
