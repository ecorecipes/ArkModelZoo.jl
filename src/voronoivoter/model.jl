function voronoivoter_world(; initial_capacity::Int = 1024)
    return World(
        VoterPoint;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function voronoivoter_systems()
    return (
        InitVoronoiVoterSystem(),
        VoronoiVoterUpdateSystem(),
        VoronoiStatsSystem(),
        VoronoiTerminationSystem(),
    )
end

function voronoivoter_model(params::VoronoiVoterParams = VoronoiVoterParams())
    world = voronoivoter_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, VoronoiGrid(params.grid_size, params.grid_size))
    add_resource!(world, VoronoiNetwork())
    add_resource!(world, VoronoiStats())
    scheduler = Scheduler(world, voronoivoter_systems())
    initialize!(scheduler)
    return scheduler
end

struct VoronoiVoterObserver end

function voronoivoter_headers(::VoronoiVoterObserver)
    return ["NColors"]
end

function voronoivoter_values(::VoronoiVoterObserver, world::World)
    stats = get_resource(world, VoronoiStats)
    return Float64[stats.n_colors]
end

function run_voronoivoter(; params::VoronoiVoterParams = VoronoiVoterParams(), observe::Bool = true)
    scheduler = voronoivoter_model(params)
    obs = VoronoiVoterObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, voronoivoter_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, voronoivoter_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
