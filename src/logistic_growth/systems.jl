# --- Initialization ---

struct InitLGSystem <: System end

function initialize!(::InitLGSystem, world::World)
    params = get_resource(world, LGParams)
    state = get_resource(world, LGState)
    state.stock = params.initial_stock
    return nothing
end

# --- Go: logistic growth step ---
# NetLogo SD: inflow = stock * (1 - stock), dt = 0.01

struct LGGoSystem <: System end

function update!(::LGGoSystem, world::World)
    params = get_resource(world, LGParams)
    state = get_resource(world, LGState)
    s = state.stock
    inflow = s * (1.0 - s)
    state.stock = s + params.dt * inflow
    return nothing
end

# --- Termination ---

struct LGTerminationSystem <: System end

function update!(::LGTerminationSystem, world::World)
    params = get_resource(world, LGParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
