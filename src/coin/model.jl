function coin_world(; initial_capacity::Int = 128)
    return World(
        CoinAgent;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function coin_systems()
    return (
        InitCoinSystem(),
        CoinActionSystem(),
        CoinRecomputeSystem(),
        CoinTerminationSystem(),
    )
end

function coin_model(params::CoinParams = CoinParams())
    world = coin_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, CoinState())
    scheduler = Scheduler(world, coin_systems())
    initialize!(scheduler)
    return scheduler
end

struct CoinObserver end

function coin_headers(::CoinObserver)
    return ["CurrentUtility"]
end

function coin_values(::CoinObserver, world::World)
    state = get_resource(world, CoinState)
    return Float64[state.current_utility]
end

function run_coin(; params::CoinParams = CoinParams(), observe::Bool = true)
    scheduler = coin_model(params)
    obs = CoinObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, coin_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, coin_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
