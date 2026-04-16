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
    _add_standard_resources!(world, params)
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
    return _run_model(coin_model, CoinObserver(), coin_values; params, observe)
end
