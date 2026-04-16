function ca1d_world(; initial_capacity::Int = 64)
    return World(CA1DDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function ca1d_systems()
    return (InitCA1DSystem(), CA1DGoSystem(), CA1DTerminationSystem())
end

function ca1d_model(params::CA1DParams = CA1DParams())
    world = ca1d_world()
    _add_standard_resources!(world, params)
    add_resource!(world, CA1DGrid(params.grid_width, params.grid_height))
    add_resource!(world, CA1DStats())
    scheduler = Scheduler(world, ca1d_systems())
    initialize!(scheduler)
    return scheduler
end

struct CA1DObserver end

function ca1d_headers(::CA1DObserver)
    return ["CurrentRow", "DensityOn"]
end

function ca1d_values(::CA1DObserver, world::World)
    stats = get_resource(world, CA1DStats)
    g = get_resource(world, CA1DGrid)
    # NetLogo current-row counts down from max-pycor (grid_height - 1)
    nl_current_row = Float64(g.height - stats.current_row)
    return Float64[nl_current_row, stats.density_on]
end

function run_ca_1d_elementary(; params::CA1DParams = CA1DParams(), observe::Bool = true)
    return _run_model(ca1d_model, CA1DObserver(), ca1d_values; params, observe)
end
