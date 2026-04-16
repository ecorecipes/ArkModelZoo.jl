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
    _add_standard_resources!(world, params)
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
    return _run_model(voter_model, VoterObserver(), voter_values; params, observe)
end
