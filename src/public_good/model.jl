function pg_world(; initial_capacity::Int = 64)
    return World(PGStudent; initial_capacity = initial_capacity, allow_mutable = true)
end

function pg_systems()
    return (
        InitPGSystem(),
        PGGoSystem(),
        PGTerminationSystem(),
    )
end

function pg_model(params::PGParams = PGParams())
    world = pg_world()
    _add_standard_resources!(world, params)
    add_resource!(world, PGStats())
    scheduler = Scheduler(world, pg_systems())
    initialize!(scheduler)
    return scheduler
end

struct PGObserver end

function pg_headers(::PGObserver)
    return ["MeanMoney", "MeanInvestment", "Bank"]
end

function pg_values(::PGObserver, world::World)
    stats = get_resource(world, PGStats)
    return Float64[stats.mean_money, stats.mean_investment, stats.bank]
end

function run_public_good(; params::PGParams = PGParams(), observe::Bool = true)
    return _run_model(pg_model, PGObserver(), pg_values; params, observe)
end
