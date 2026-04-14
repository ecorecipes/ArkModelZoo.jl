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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = teamassembly_model(params)
    obs = TeamAssemblyObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, teamassembly_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, teamassembly_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
