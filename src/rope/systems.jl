# --- Initialization ---

struct InitRopeSystem <: System end

function initialize!(::InitRopeSystem, world::World)
    params = get_resource(world, RopeParams)
    state = get_resource(world, RopeState)
    stats = get_resource(world, RopeStats)
    # All ypos/yvel start at 0, all visible
    fill!(state.ypos, 0.0)
    fill!(state.yvel, 0.0)
    fill!(state.visible, true)
    # NetLogo doesn't set n-visible in setup; defaults to 0 until first go.
    stats.n_visible = 0
    return nothing
end

# --- Wave Update ---

struct RopeUpdateSystem <: System end

function update!(::RopeUpdateSystem, world::World)
    params = get_resource(world, RopeParams)
    state = get_resource(world, RopeState)
    tick = get_resource(world, Tick)

    n = state.n
    t = tick.tick
    friction = params.friction
    frequency = params.frequency
    amplitude = params.amplitude
    y_min = Float64(params.y_min)
    y_max = Float64(params.y_max)
    damping = (1000 - friction) / 1000.0

    # Green turtle (index 1): driver
    if t > 100
        state.ypos[1] = amplitude * sind(frequency * t)
    else
        state.ypos[1] = (t / 100.0) * amplitude * sind(frequency * t)
    end
    # NetLogo visibility: patch-at 0 (ypos - ycor) != nobody
    # In a non-wrapping world the valid y-range is [min_pycor - 0.5, max_pycor + 0.5]
    state.visible[1] = (y_min - 0.5) <= state.ypos[1] <= (y_max + 0.5)

    # Red turtles (indices 2:n-1): compute yvel from neighbors
    for i in 2:(n - 1)
        state.yvel[i] += (state.ypos[i - 1] - state.ypos[i]) +
                          (state.ypos[i + 1] - state.ypos[i])
        state.yvel[i] *= damping
    end

    # Red turtles: update ypos and visibility
    for i in 2:(n - 1)
        state.ypos[i] += state.yvel[i]
        state.visible[i] = (y_min - 0.5) <= state.ypos[i] <= (y_max + 0.5)
    end

    # Blue turtle (index n) stays at ypos=0, always visible
    return nothing
end

# --- Stats ---

struct RopeStatsSystem <: System end

function update!(::RopeStatsSystem, world::World)
    state = get_resource(world, RopeState)
    stats = get_resource(world, RopeStats)
    stats.n_visible = count(state.visible)
    return nothing
end

# --- Termination ---

struct RopeTerminationSystem <: System end

function update!(::RopeTerminationSystem, world::World)
    params = get_resource(world, RopeParams)
    tick = get_resource(world, Tick)
    # tick.tick is the count before this step's increment; after the step
    # it becomes tick.tick + 1.  Stop so that exactly max_ticks updates run.
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
