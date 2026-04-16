function ethnocentrism_world(; initial_capacity::Int = 4096)
    return World(
        EthnoPosition,
        Strategy,
        EthnoColor,
        PTR;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function ethnocentrism_systems()
    return (
        InitEthnoSystem(),
        ImmigrationSystem(),
        InteractionSystem(),
        EthnoReproductionSystem(),
        EthnoDeathSystem(),
        EthnoStatsSystem(),
        EthnoTerminationSystem(),
    )
end

function ethnocentrism_model(params::EthnocentrismParams = EthnocentrismParams())
    world = ethnocentrism_world()
    _add_standard_resources!(world, params)
    add_resource!(world, EthnoGrid(params.grid_size, params.grid_size))
    add_resource!(world, EthnoStats())
    scheduler = Scheduler(world, ethnocentrism_systems())
    initialize!(scheduler)
    return scheduler
end

struct EthnocentrismObserver end

function ethnocentrism_headers(::EthnocentrismObserver)
    return ["CC_Altruist", "CD_Ethnocentric", "DC_Cosmopolitan", "DD_Egoist", "Population"]
end

function ethnocentrism_values(::EthnocentrismObserver, world::World)
    stats = get_resource(world, EthnoStats)
    cc = isempty(stats.cc_history) ? 0.0 : last(stats.cc_history)
    cd = isempty(stats.cd_history) ? 0.0 : last(stats.cd_history)
    dc = isempty(stats.dc_history) ? 0.0 : last(stats.dc_history)
    dd = isempty(stats.dd_history) ? 0.0 : last(stats.dd_history)
    return Float64[cc, cd, dc, dd, stats.total_population]
end

function run_ethnocentrism(; params::EthnocentrismParams = EthnocentrismParams(), observe::Bool = true)
    return _run_model(ethnocentrism_model, EthnocentrismObserver(), ethnocentrism_values; params, observe)
end
