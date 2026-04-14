# --- Helpers ---

function _rhino_weighted_choice(rng, items, weights)
    total = sum(weights)
    if total <= 0.0
        return items[rand(rng, 1:length(items))]
    end
    r = rand(rng) * total
    cumul = 0.0
    for (item, w) in zip(items, weights)
        cumul += w
        if cumul >= r
            return item
        end
    end
    return items[end]
end

@inline function _rhino_dist(x1, y1, x2, y2)
    return sqrt((x1 - x2)^2 + (y1 - y2)^2)
end

# --- Initialization ---

struct InitRhinoSystem <: System end

function initialize!(::InitRhinoSystem, world::World)
    state = get_resource(world, RhinoState)
    stats = get_resource(world, RhinoStats)
    stats.n_rhinos = sum(state.rhino_alive)
    stats.n_poachers = sum(state.poacher_alive)
    stats.total_killed = state.total_killed
    return nothing
end

# --- Resource Regrowth ---

struct RhinoResourceGrowSystem <: System end

function update!(::RhinoResourceGrowSystem, world::World)
    params = get_resource(world, RhinoParams)
    state = get_resource(world, RhinoState)

    for x in 1:state.width, y in 1:state.height
        if state.roughness[x, y] < 1.0
            state.resources[x, y] += params.resource_regrow_rate *
                (state.max_resources[x, y] - state.resources[x, y])
        end
    end
    return nothing
end

# --- Activity Decay ---

struct RhinoActivityDecaySystem <: System end

function update!(::RhinoActivityDecaySystem, world::World)
    params = get_resource(world, RhinoParams)
    state = get_resource(world, RhinoState)

    state.rhino_activity .*= params.activity_decay
    return nothing
end

# --- Rhino Forage ---

struct RhinoForageSystem <: System end

function update!(::RhinoForageSystem, world::World)
    params = get_resource(world, RhinoParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, RhinoState)
    w, h = state.width, state.height
    radius = params.rhino_forage_radius

    for i in 1:length(state.rhino_alive)
        !state.rhino_alive[i] && continue

        gx = clamp(round(Int, state.rhino_x[i]), 1, w)
        gy = clamp(round(Int, state.rhino_y[i]), 1, h)

        # Leave activity at current location
        state.rhino_activity[gx, gy] += 1.0

        # Forage: weighted random choice of neighboring cell
        candidates = Tuple{Int,Int}[]
        weights = Float64[]

        for dx in -radius:radius, dy in -radius:radius
            (dx == 0 && dy == 0) && continue
            nx = gx + dx
            ny = gy + dy
            (nx < 1 || nx > w || ny < 1 || ny > h) && continue
            state.roughness[nx, ny] >= 1.0 && continue

            res_score = state.resources[nx, ny]
            home_dist = _rhino_dist(Float64(nx), Float64(ny),
                                    state.rhino_home_x[i], state.rhino_home_y[i])
            home_score = max(0.0, 1.0 - home_dist / 50.0)

            score = params.resource_weight * res_score + params.home_weight * home_score * 10.0
            if score > 0.0
                push!(candidates, (nx, ny))
                push!(weights, score)
            end
        end

        if !isempty(candidates)
            chosen = _rhino_weighted_choice(rng, candidates, weights)
            state.rhino_x[i] = Float64(chosen[1])
            state.rhino_y[i] = Float64(chosen[2])
        else
            angle = rand(rng) * 2π
            state.rhino_x[i] = clamp(state.rhino_x[i] + cos(angle) * 2.0, 1.0, Float64(w))
            state.rhino_y[i] = clamp(state.rhino_y[i] + sin(angle) * 2.0, 1.0, Float64(h))
        end

        # Consume resources
        new_gx = clamp(round(Int, state.rhino_x[i]), 1, w)
        new_gy = clamp(round(Int, state.rhino_y[i]), 1, h)
        consumed = min(state.resources[new_gx, new_gy], 1.0)
        state.resources[new_gx, new_gy] -= consumed

        # Slowly drift home range
        state.rhino_home_x[i] = 0.99 * state.rhino_home_x[i] + 0.01 * state.rhino_x[i]
        state.rhino_home_y[i] = 0.99 * state.rhino_home_y[i] + 0.01 * state.rhino_y[i]

        state.rhino_ticks_alive[i] += 1
    end
    return nothing
end

# --- Rhino Reproduction ---

struct RhinoReproduceSystem <: System end

function update!(::RhinoReproduceSystem, world::World)
    params = get_resource(world, RhinoParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, RhinoState)
    w, h = state.width, state.height

    n_alive = sum(state.rhino_alive)
    n_alive >= params.max_rhinos && return nothing

    for i in 1:length(state.rhino_alive)
        !state.rhino_alive[i] && continue
        state.rhino_ticks_alive[i] < 50 && continue

        if rand(rng) < params.rhino_reproduce_prob
            n_alive >= params.max_rhinos && break

            slot = findfirst(x -> !x, state.rhino_alive)
            slot === nothing && break

            state.rhino_alive[slot] = true
            state.rhino_x[slot] = clamp(state.rhino_x[i] + (rand(rng) - 0.5) * 2.0, 1.0, Float64(w))
            state.rhino_y[slot] = clamp(state.rhino_y[i] + (rand(rng) - 0.5) * 2.0, 1.0, Float64(h))
            state.rhino_heading[slot] = rand(rng) * 360.0
            state.rhino_home_x[slot] = state.rhino_x[slot]
            state.rhino_home_y[slot] = state.rhino_y[slot]
            state.rhino_ticks_alive[slot] = 0
            n_alive += 1
        end
    end
    return nothing
end

# --- Poacher System ---

struct RhinoPoacherSystem <: System end

function update!(::RhinoPoacherSystem, world::World)
    params = get_resource(world, RhinoParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, RhinoState)
    w, h = state.width, state.height

    for i in 1:state.n_poachers
        !state.poacher_alive[i] && continue
        state.poacher_caught[i] && continue

        if state.poacher_goal[i] == 0
            # Journey to crime: move toward high rhino activity
            gx = clamp(round(Int, state.poacher_x[i]), 1, w)
            gy = clamp(round(Int, state.poacher_y[i]), 1, h)

            best_dx, best_dy = 0.0, 0.0
            best_activity = 0.0
            search_r = round(Int, params.poacher_detect_range)

            for dx in -search_r:search_r, dy in -search_r:search_r
                (dx == 0 && dy == 0) && continue
                nx = gx + dx
                ny = gy + dy
                (nx < 1 || nx > w || ny < 1 || ny > h) && continue
                if state.rhino_activity[nx, ny] > best_activity
                    best_activity = state.rhino_activity[nx, ny]
                    best_dx = Float64(dx)
                    best_dy = Float64(dy)
                end
            end

            if best_activity > 0.1
                dist = sqrt(best_dx^2 + best_dy^2)
                if dist > 0.0
                    state.poacher_x[i] += best_dx / dist * 1.5
                    state.poacher_y[i] += best_dy / dist * 1.5
                end
                state.poacher_goal[i] = 1
            else
                angle = state.poacher_heading[i] + (rand(rng) - 0.5) * 60.0
                state.poacher_heading[i] = angle
                θ = deg2rad(angle)
                state.poacher_x[i] += sin(θ) * 1.5
                state.poacher_y[i] += cos(θ) * 1.5
            end

        elseif state.poacher_goal[i] == 1
            # Hunting: try to kill a rhino
            killed_this_step = false
            for j in 1:length(state.rhino_alive)
                !state.rhino_alive[j] && continue
                d = _rhino_dist(state.poacher_x[i], state.poacher_y[i],
                                state.rhino_x[j], state.rhino_y[j])
                if d < params.poacher_kill_range
                    state.rhino_alive[j] = false
                    state.total_killed += 1
                    killed_this_step = true
                    break
                end
            end

            if killed_this_step
                state.poacher_goal[i] = 2
            else
                angle = state.poacher_heading[i] + (rand(rng) - 0.5) * 30.0
                state.poacher_heading[i] = angle
                θ = deg2rad(angle)
                state.poacher_x[i] += sin(θ) * 1.0
                state.poacher_y[i] += cos(θ) * 1.0
                if rand(rng) < 0.1
                    state.poacher_goal[i] = 0
                end
            end

        else  # goal == 2: flee toward nearest edge
            edge_dx = state.poacher_x[i] < Float64(w) / 2.0 ? -1.5 : 1.5
            edge_dy = state.poacher_y[i] < Float64(h) / 2.0 ? -1.5 : 1.5
            state.poacher_x[i] += edge_dx + (rand(rng) - 0.5)
            state.poacher_y[i] += edge_dy + (rand(rng) - 0.5)

            # Reached edge → respawn at new edge position
            if state.poacher_x[i] <= 1.0 || state.poacher_x[i] >= Float64(w) ||
               state.poacher_y[i] <= 1.0 || state.poacher_y[i] >= Float64(h)
                state.poacher_goal[i] = 0
                if rand(rng) < 0.5
                    state.poacher_x[i] = rand(rng) < 0.5 ? 1.0 : Float64(w)
                    state.poacher_y[i] = rand(rng) * (h - 1) + 1.0
                else
                    state.poacher_x[i] = rand(rng) * (w - 1) + 1.0
                    state.poacher_y[i] = rand(rng) < 0.5 ? 1.0 : Float64(h)
                end
            end
        end

        state.poacher_x[i] = clamp(state.poacher_x[i], 1.0, Float64(w))
        state.poacher_y[i] = clamp(state.poacher_y[i], 1.0, Float64(h))
    end
    return nothing
end

# --- Ranger System ---

struct RhinoRangerSystem <: System end

function update!(::RhinoRangerSystem, world::World)
    params = get_resource(world, RhinoParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, RhinoState)
    w, h = state.width, state.height

    for i in 1:state.n_rangers
        angle = state.ranger_heading[i] + (rand(rng) - 0.5) * 90.0
        state.ranger_heading[i] = angle
        θ = deg2rad(angle)
        state.ranger_x[i] = clamp(state.ranger_x[i] + sin(θ) * 2.0, 1.0, Float64(w))
        state.ranger_y[i] = clamp(state.ranger_y[i] + cos(θ) * 2.0, 1.0, Float64(h))

        for j in 1:state.n_poachers
            !state.poacher_alive[j] && continue
            state.poacher_caught[j] && continue
            d = _rhino_dist(state.ranger_x[i], state.ranger_y[i],
                            state.poacher_x[j], state.poacher_y[j])
            if d < params.ranger_detect_range
                state.poacher_caught[j] = true
                state.poacher_alive[j] = false
            end
        end
    end
    return nothing
end

# --- Stats ---

struct RhinoStatsSystem <: System end

function update!(::RhinoStatsSystem, world::World)
    state = get_resource(world, RhinoState)
    stats = get_resource(world, RhinoStats)
    stats.n_rhinos = sum(state.rhino_alive)
    stats.n_poachers = sum(state.poacher_alive)
    stats.total_killed = state.total_killed
    return nothing
end

# --- Termination ---

struct RhinoTerminationSystem <: System end

function update!(::RhinoTerminationSystem, world::World)
    params = get_resource(world, RhinoParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
