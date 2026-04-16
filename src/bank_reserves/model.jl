function bank_reserves_world(; initial_capacity::Int = 256)
    return World(
        BRESPosition,
        BRESAccount;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function bank_reserves_systems()
    return (
        InitBRESSystem(),
        BRESGoSystem(),
        BRESTerminationSystem(),
    )
end

function bank_reserves_model(params::BRESParams = BRESParams())
    world = bank_reserves_world()
    _add_standard_resources!(world, params)
    add_resource!(world, BRESBank())
    add_resource!(world, BRESStats())
    scheduler = Scheduler(world, bank_reserves_systems())
    initialize!(scheduler)
    return scheduler
end

struct BRESObserver end

function bank_reserves_headers(::BRESObserver)
    return ["Rich", "Poor", "MiddleClass", "MoneyTotal"]
end

function bank_reserves_values(::BRESObserver, world::World)
    stats = get_resource(world, BRESStats)
    return Float64[stats.rich, stats.poor, stats.middle_class, stats.money_total]
end

function run_bank_reserves(; params::BRESParams = BRESParams(), observe::Bool = true)
    return _run_model(bank_reserves_model, BRESObserver(), bank_reserves_values; params, observe)
end
