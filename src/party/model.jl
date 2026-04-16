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
    _add_standard_resources!(world, params)
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
    return _run_model(party_model, PartyObserver(), party_values; params, observe)
end
