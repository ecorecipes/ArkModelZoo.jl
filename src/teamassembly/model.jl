function teamassembly_world(; initial_capacity::Int = 128)
    return World(TeamDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function teamassembly_systems()
    return (
        InitTeamSystem(),
        TeamGoSystem(),
        TeamTerminationSystem(),
    )
end

function teamassembly_model(params::TeamAssemblyParams = TeamAssemblyParams())
    world = teamassembly_world()
    _add_standard_resources!(world, params)
    add_resource!(world, TeamState())
    add_resource!(world, TeamStats())
    scheduler = Scheduler(world, teamassembly_systems())
    initialize!(scheduler)
    return scheduler
end

struct TeamAssemblyObserver end

function teamassembly_headers(::TeamAssemblyObserver)
    return ["GiantComponentSize"]
end

function teamassembly_values(::TeamAssemblyObserver, world::World)
    stats = get_resource(world, TeamStats)
    return Float64[stats.giant_component_size]
end

function run_teamassembly(; params::TeamAssemblyParams = TeamAssemblyParams(), observe::Bool = true)
    return _run_model(teamassembly_model, TeamAssemblyObserver(), teamassembly_values; params, observe)
end
