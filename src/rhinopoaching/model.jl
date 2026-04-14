function _build_rhino_state(params::RhinoParams, rng)
    w, h = params.width, params.height

    resources = zeros(Float64, w, h)
    max_resources = zeros(Float64, w, h)
    roughness = zeros(Float64, w, h)

    for x in 1:w, y in 1:h
        resources[x, y] = -log(max(rand(rng), 1e-10)) * 10.0
        max_resources[x, y] = resources[x, y]
        roughness[x, y] = rand(rng) < params.max_roughness ? 1.0 : 0.0
    end

    mr = params.max_rhinos
    rhino_x = zeros(Float64, mr)
    rhino_y = zeros(Float64, mr)
    rhino_heading = zeros(Float64, mr)
    rhino_alive = fill(false, mr)
    rhino_home_x = zeros(Float64, mr)
    rhino_home_y = zeros(Float64, mr)
    rhino_ticks = zeros(Int, mr)

    for i in 1:params.num_rhinos
        rx = rand(rng) * (w - 1) + 1.0
        ry = rand(rng) * (h - 1) + 1.0
        rhino_x[i] = rx
        rhino_y[i] = ry
        rhino_heading[i] = rand(rng) * 360.0
        rhino_alive[i] = true
        rhino_home_x[i] = rx
        rhino_home_y[i] = ry
    end

    np = params.num_poachers
    poacher_x = zeros(Float64, np)
    poacher_y = zeros(Float64, np)
    poacher_heading = zeros(Float64, np)
    poacher_alive = fill(true, np)
    poacher_goal = zeros(Int, np)
    poacher_caught = fill(false, np)

    for i in 1:np
        if rand(rng) < 0.5
            poacher_x[i] = rand(rng) < 0.5 ? 1.0 : Float64(w)
            poacher_y[i] = rand(rng) * (h - 1) + 1.0
        else
            poacher_x[i] = rand(rng) * (w - 1) + 1.0
            poacher_y[i] = rand(rng) < 0.5 ? 1.0 : Float64(h)
        end
        poacher_heading[i] = rand(rng) * 360.0
    end

    nrg = params.num_rangers
    ranger_x = zeros(Float64, nrg)
    ranger_y = zeros(Float64, nrg)
    ranger_heading = zeros(Float64, nrg)

    cx, cy = w / 2.0, h / 2.0
    offset = min(w, h) / 4.0
    corners = [(cx - offset, cy - offset), (cx + offset, cy - offset),
               (cx - offset, cy + offset), (cx + offset, cy + offset)]
    for i in 1:min(nrg, 4)
        ranger_x[i] = corners[i][1]
        ranger_y[i] = corners[i][2]
        ranger_heading[i] = rand(rng) * 360.0
    end
    for i in 5:nrg
        ranger_x[i] = cx + (rand(rng) - 0.5) * offset
        ranger_y[i] = cy + (rand(rng) - 0.5) * offset
        ranger_heading[i] = rand(rng) * 360.0
    end

    return RhinoState(
        params.num_rhinos, rhino_x, rhino_y, rhino_heading, rhino_alive,
        rhino_home_x, rhino_home_y, rhino_ticks,
        np, poacher_x, poacher_y, poacher_heading, poacher_alive, poacher_goal, poacher_caught,
        nrg, ranger_x, ranger_y, ranger_heading,
        w, h, resources, max_resources, roughness, zeros(Float64, w, h),
        0,
    )
end

function rhinopoaching_world(; initial_capacity::Int = 128)
    return World(RhinoDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function rhinopoaching_systems()
    return (
        InitRhinoSystem(),
        RhinoResourceGrowSystem(),
        RhinoActivityDecaySystem(),
        RhinoForageSystem(),
        RhinoReproduceSystem(),
        RhinoPoacherSystem(),
        RhinoRangerSystem(),
        RhinoStatsSystem(),
        RhinoTerminationSystem(),
    )
end

function rhinopoaching_model(params::RhinoParams = RhinoParams())
    world = rhinopoaching_world()
    rng_resource = RNGResource(Xoshiro(params.seed))
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, rng_resource)
    add_resource!(world, deepcopy(params))
    add_resource!(world, _build_rhino_state(params, rng_resource.rng))
    add_resource!(world, RhinoStats())
    scheduler = Scheduler(world, rhinopoaching_systems())
    initialize!(scheduler)
    return scheduler
end

struct RhinoObserver end

function rhino_headers(::RhinoObserver)
    return ["Rhinos", "Poachers", "TotalKilled"]
end

function rhino_values(::RhinoObserver, world::World)
    stats = get_resource(world, RhinoStats)
    return Float64[stats.n_rhinos, stats.n_poachers, stats.total_killed]
end

function run_rhinopoaching(; params::RhinoParams = RhinoParams(), observe::Bool = true)
    scheduler = rhinopoaching_model(params)
    obs = RhinoObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, rhino_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, rhino_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
