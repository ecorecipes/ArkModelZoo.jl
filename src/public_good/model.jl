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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = pg_model(params)
    obs = PGObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, pg_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, pg_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
