function party_world(; initial_capacity::Int = 256)
    return World(
        PartySex,
        PartyState,
        PartyTag;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function party_systems()
    return (
        InitPartySystem(),
        PartyUpdateSystem(),
        PartyStatsSystem(),
        PartyTerminationSystem(),
    )
end

function party_model(params::PartyParams = PartyParams())
    world = party_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, PartyGroupSites(params.world_width, params.num_groups))
    add_resource!(world, PartyStats())
    scheduler = Scheduler(world, party_systems())
    initialize!(scheduler)
    return scheduler
end

struct PartyObserver end

function party_headers(::PartyObserver)
    return ["BoringGroups"]
end

function party_values(::PartyObserver, world::World)
    stats = get_resource(world, PartyStats)
    return Float64[stats.boring_groups]
end

function run_party(; params::PartyParams = PartyParams(), observe::Bool = true)
    scheduler = party_model(params)
    obs = PartyObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, party_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, party_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
