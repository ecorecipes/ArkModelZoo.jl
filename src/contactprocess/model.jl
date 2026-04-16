function contactprocess_world(; initial_capacity::Int = 128)
    return World(
        ContactDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function contactprocess_systems()
    return (
        InitContactSystem(),
        ContactUpdateSystem(),
        ContactStatsSystem(),
        ContactTerminationSystem(),
    )
end

function contactprocess_model(params::ContactProcessParams = ContactProcessParams())
    world = contactprocess_world()
    _add_standard_resources!(world, params)
    add_resource!(world, ContactGrid(params.grid_width, params.grid_height))
    add_resource!(world, ContactStats())
    scheduler = Scheduler(world, contactprocess_systems())
    initialize!(scheduler)
    return scheduler
end

struct ContactProcessObserver end

function contactprocess_headers(::ContactProcessObserver)
    return ["POccupied"]
end

function contactprocess_values(::ContactProcessObserver, world::World)
    stats = get_resource(world, ContactStats)
    return Float64[stats.p_occupied]
end

function run_contactprocess(; params::ContactProcessParams = ContactProcessParams(), observe::Bool = true)
    return _run_model(contactprocess_model, ContactProcessObserver(), contactprocess_values; params, observe)
end
