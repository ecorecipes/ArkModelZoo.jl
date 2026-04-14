function daisyworld_world(; initial_capacity::Int = 2048)
    return World(
        DaisyPosition,
        DaisyAge,
        Albedo,
        WhiteDaisy,
        BlackDaisy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function daisyworld_systems()
    return (
        InitDaisyworldSystem(),
        CalcTemperatureSystem(),
        DiffuseTemperatureSystem(),
        SurvivabilitySystem(),
        DaisyStatsSystem(),
        DaisyworldTerminationSystem(),
    )
end

function daisyworld_model(params::DaisyworldParams = DaisyworldParams())
    world = daisyworld_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, TemperatureGrid(params.grid_size, params.grid_size))
    add_resource!(world, DaisyStats())
    scheduler = Scheduler(world, daisyworld_systems())
    initialize!(scheduler)
    return scheduler
end

struct DaisyworldObserver end

function daisyworld_headers(::DaisyworldObserver)
    return ["GlobalTemp", "NumWhites", "NumBlacks", "SolarLuminosity"]
end

function daisyworld_values(::DaisyworldObserver, world::World)
    stats = get_resource(world, DaisyStats)
    return Float64[stats.global_temperature, stats.num_whites,
                    stats.num_blacks, stats.solar_luminosity]
end

function run_daisyworld(; params::DaisyworldParams = DaisyworldParams(), observe::Bool = true)
    scheduler = daisyworld_model(params)
    obs = DaisyworldObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, daisyworld_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, daisyworld_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
