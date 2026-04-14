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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = ethnocentrism_model(params)
    obs = EthnocentrismObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, ethnocentrism_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, ethnocentrism_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
