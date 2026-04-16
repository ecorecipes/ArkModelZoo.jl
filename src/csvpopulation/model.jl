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
    _add_standard_resources!(world, params)
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
    return _run_model(csvpopulation_model, CsvPopObserver(), csvpopulation_values; params, observe)
end
