function _build_aecon_state(params::AEconParams, rng)
    n = 2 * params.population
    w, h = params.width, params.height
    farm_yield = zeros(Float64, w, h)
    half_w = div(w, 2)
    for x in 1:half_w, y in 1:h
        farm_yield[x, y] = Float64(rand(rng, 0:9))
    end

    state = AEconState(
        n,
        vcat(fill(true, params.population), fill(false, params.population)),
        zeros(Int, n), zeros(Int, n),
        fill(params.initial_money, n),
        zeros(Float64, n), zeros(Float64, n),
        zeros(Float64, n),
        fill(true, n),
        zeros(Float64, n),
        1000.0, 500.0, 5000.0,
        1.0, 1.0,
        5000.0, 5000.0,
        params.interest_rate, params.interest_rate,
        200.0, 60.0,
        w, h, farm_yield,
    )

    for i in 1:n
        if state.is_farmer[i]
            state.x[i] = rand(rng, 1:half_w)
        else
            state.x[i] = rand(rng, (half_w + 1):w)
            state.produce[i] = 20.0  # initial produce for professionals
        end
        state.y[i] = rand(rng, 1:h)
    end

    return state
end

function artificialeconomy_world(; initial_capacity::Int = 128)
    return World(AEconDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function artificialeconomy_systems()
    return (
        InitAEconSystem(),
        AEconMoveProduceSystem(),
        AEconPriceSystem(),
        AEconTradeSystem(),
        AEconFinanceSystem(),
        AEconSwitchSystem(),
        AEconStatsSystem(),
        AEconTerminationSystem(),
    )
end

function artificialeconomy_model(params::AEconParams = AEconParams())
    world = artificialeconomy_world()
    rng_resource = RNGResource(Xoshiro(params.seed))
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, rng_resource)
    add_resource!(world, deepcopy(params))
    add_resource!(world, _build_aecon_state(params, rng_resource.rng))
    add_resource!(world, AEconStats())
    scheduler = Scheduler(world, artificialeconomy_systems())
    initialize!(scheduler)
    return scheduler
end

struct AEconObserver end

function aecon_headers(::AEconObserver)
    return ["Farmers", "Professionals", "MeanMoney", "ProducePrice", "WidgetPrice"]
end

function aecon_values(::AEconObserver, world::World)
    stats = get_resource(world, AEconStats)
    return Float64[stats.n_farmers, stats.n_professionals, stats.mean_money,
                   stats.produce_price, stats.widget_price]
end

function run_artificialeconomy(; params::AEconParams = AEconParams(), observe::Bool = true)
    return _run_model(artificialeconomy_model, AEconObserver(), aecon_values; params, observe)
end
