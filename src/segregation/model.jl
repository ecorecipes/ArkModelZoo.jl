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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = segregation_model(params)
    obs = SegregationObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, segregation_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, segregation_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
