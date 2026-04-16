function segregation_world(; initial_capacity::Int = 4096)
    return World(
        GridPosition,
        AgentColor,
        Happiness;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function segregation_systems()
    return (
        InitSegregationSystem(),
        MoveUnhappySystem(),          # Move first (using happiness from previous tick)
        UpdateHappinessSystem(),       # Then recompute happiness after moves
        SegregationTerminationSystem(),
    )
end

function segregation_model(params::SegregationParams = SegregationParams())
    world = segregation_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SegregationGrid(params.grid_width, params.grid_height))
    add_resource!(world, SegregationStats())
    scheduler = Scheduler(world, segregation_systems())
    initialize!(scheduler)
    return scheduler
end

struct SegregationObserver end

function segregation_headers(::SegregationObserver)
    return ["PercentSimilar", "PercentUnhappy", "NumUnhappy", "NumHappy"]
end

function segregation_values(::SegregationObserver, world::World)
    stats = get_resource(world, SegregationStats)
    return Float64[stats.percent_similar, stats.percent_unhappy,
                    stats.num_unhappy, stats.num_happy]
end

function run_segregation(; params::SegregationParams = SegregationParams(), observe::Bool = true)
    return _run_model(segregation_model, SegregationObserver(), segregation_values; params, observe)
end
