function csvpopulation_world(; initial_capacity::Int = 128)
    return World(CsvPopDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function csvpopulation_systems()
    return (InitCsvPopSystem(), CsvPopGoSystem(), CsvPopTerminationSystem())
end

function csvpopulation_model(params::CsvPopParams = CsvPopParams())
    w = params.grid_xmax - params.grid_xmin + 1
    h = params.grid_ymax - params.grid_ymin + 1
    world = csvpopulation_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, CsvPopGrid(w, h))
    add_resource!(world, CsvPopState())
    add_resource!(world, CsvPopStats())
    scheduler = Scheduler(world, csvpopulation_systems())
    initialize!(scheduler)
    return scheduler
end

struct CsvPopObserver end

function csvpopulation_headers(::CsvPopObserver)
    return ["TotalEnergy", "AvgAge", "PopCount"]
end

function csvpopulation_values(::CsvPopObserver, world::World)
    stats = get_resource(world, CsvPopStats)
    return Float64[stats.total_energy, stats.avg_age, Float64(stats.pop_count)]
end

function run_csvpopulation(; params::CsvPopParams = CsvPopParams(), observe::Bool = true)
    scheduler = csvpopulation_model(params)
    obs = CsvPopObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, csvpopulation_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, csvpopulation_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
