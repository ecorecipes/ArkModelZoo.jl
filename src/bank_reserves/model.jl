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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = bank_reserves_model(params)
    obs = BRESObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, bank_reserves_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, bank_reserves_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
