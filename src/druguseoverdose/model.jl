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
    _add_standard_resources!(world, params)
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
    return _run_model(druguseoverdose_model, DUOObserver(), druguseoverdose_values; params, observe)
end
