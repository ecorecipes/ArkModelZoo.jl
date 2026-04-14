function voter_world(; initial_capacity::Int = 128)
    return World(
        VoterDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function voter_systems()
    return (
        InitVoterSystem(),
        VoterUpdateSystem(),
        VoterStatsSystem(),
        VoterTerminationSystem(),
    )
end

function voter_model(params::VoterParams = VoterParams())
    world = voter_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, VoterGrid(params.grid_width, params.grid_height))
    add_resource!(world, VoterStats())
    scheduler = Scheduler(world, voter_systems())
    initialize!(scheduler)
    return scheduler
end

struct VoterObserver end

function voter_headers(::VoterObserver)
    return ["NColors"]
end

function voter_values(::VoterObserver, world::World)
    stats = get_resource(world, VoterStats)
    return Float64[stats.n_colors]
end

function run_voter(; params::VoterParams = VoterParams(), observe::Bool = true)
    scheduler = voter_model(params)
    obs = VoterObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, voter_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, voter_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
