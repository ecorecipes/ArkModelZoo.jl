function fungalbioremediation_world(; initial_capacity::Int = 256)
    return World(
        FBRDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function fungalbioremediation_systems()
    return (
        InitFBRSystem(),
        FBRGoSystem(),
        FBRTerminationSystem(),
    )
end

function fungalbioremediation_model(params::FBRParams = FBRParams())
    world = fungalbioremediation_world()
    sp = get(FBR_SPECIES, params.fungi_species,
             FBRFungiSpecies(33.5, 4.0, 2.5, 5.0))
    _add_standard_resources!(world, params)
    add_resource!(world, FBRPatchGrid(params.grid_width, params.grid_height))
    add_resource!(world, FBRWorld(sp))
    add_resource!(world, FBRStats())
    scheduler = Scheduler(world, fungalbioremediation_systems())
    initialize!(scheduler)
    return scheduler
end

struct FBRObserver end

function fungalbioremediation_headers(::FBRObserver)
    return ["num_fungi", "num_enzymes", "num_ecs"]
end

function fungalbioremediation_values(::FBRObserver, world::World)
    stats = get_resource(world, FBRStats)
    return Float64[stats.num_fungi, stats.num_enzymes, stats.num_ecs]
end

function run_fungalbioremediation(; params::FBRParams = FBRParams(), observe::Bool = true)
    return _run_model(fungalbioremediation_model, FBRObserver(), fungalbioremediation_values; params, observe)
end
