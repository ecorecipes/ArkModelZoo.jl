function slowspread_world(; initial_capacity::Int = 128)
    return World(SSpreadDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function slowspread_systems()
    return (InitSSpreadSystem(), SSpreadGoSystem(), SSpreadTerminationSystem())
end

function slowspread_model(params::SSpreadParams = SSpreadParams())
    world = slowspread_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, SSpreadNetwork())
    add_resource!(world, SSpreadStats())
    scheduler = Scheduler(world, slowspread_systems())
    initialize!(scheduler)
    return scheduler
end

struct SSpreadObserver end

function slowspread_headers(::SSpreadObserver)
    return ["PctGreen", "PctGrey"]
end

function slowspread_values(::SSpreadObserver, world::World)
    stats = get_resource(world, SSpreadStats)
    return Float64[stats.pct_green, stats.pct_grey]
end

function run_slowspread(; params::SSpreadParams = SSpreadParams(), observe::Bool = true)
    scheduler = slowspread_model(params)
    obs = SSpreadObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, slowspread_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, slowspread_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
