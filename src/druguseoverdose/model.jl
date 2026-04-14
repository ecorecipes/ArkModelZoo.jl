function druguseoverdose_world(; initial_capacity::Int = 128)
    return World(
        DUOPosition, DUOHeading, DUOAgentState, DUOTag;
        initial_capacity = initial_capacity, allow_mutable = true,
    )
end

function druguseoverdose_systems()
    return (InitDUOSystem(), DUOGoSystem(), DUOTerminationSystem())
end

function druguseoverdose_model(params::DrugUseOverdoseParams = DrugUseOverdoseParams())
    world = druguseoverdose_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, DUOGrid())
    add_resource!(world, DUONetwork())
    add_resource!(world, DUOStats())
    scheduler = Scheduler(world, druguseoverdose_systems())
    initialize!(scheduler)
    return scheduler
end

struct DUOObserver end

function druguseoverdose_headers(::DUOObserver)
    return ["NumberOverdoses", "NumDrugUsers", "NumAlive"]
end

function druguseoverdose_values(::DUOObserver, world::World)
    stats = get_resource(world, DUOStats)
    return Float64[stats.number_overdoses, stats.num_drug_users, stats.num_alive]
end

function run_druguseoverdose(; params::DrugUseOverdoseParams = DrugUseOverdoseParams(), observe::Bool = true)
    scheduler = druguseoverdose_model(params)
    obs = DUOObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, druguseoverdose_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, druguseoverdose_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
