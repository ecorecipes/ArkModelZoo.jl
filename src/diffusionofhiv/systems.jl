# --- Initialization ---

struct InitHIVSystem <: System end

function _gis_to_grid(gis_x::Float64, gis_y::Float64, w::Int, h::Int)
    # Map GIS coords (-125..-65 lon, 28..48 lat) to grid (1..w, 1..h)
    gx = round(Int, (gis_x - (-125.0)) / ((-65.0) - (-125.0)) * (w - 1)) + 1
    gy = round(Int, (gis_y - 28.0) / (48.0 - 28.0) * (h - 1)) + 1
    return (clamp(gx, 1, w), clamp(gy, 1, h))
end

function initialize!(::InitHIVSystem, world::World)
    params = get_resource(world, HIVParams)
    rng = get_resource(world, RNGResource).rng
    st = get_resource(world, HIVState)
    stats = get_resource(world, HIVStats)
    w, h = st.width, st.height

    # Build grid centroids in grid coordinates
    centroids = Vector{Tuple{Int,Int}}(undef, 49)
    for i in 1:49
        _, cx, cy = HIV_STATE_DATA[i][1], HIV_STATE_DATA[i][2], HIV_STATE_DATA[i][3]
        centroids[i] = _gis_to_grid(Float64(cx), Float64(cy), w, h)
    end

    # Voronoi tessellation: assign each patch to nearest state centroid
    for x in 1:w, y in 1:h
        best_d = Inf
        best_s = 1
        for s in 1:49
            cx, cy = centroids[s]
            d = (x - cx)^2 + (y - cy)^2
            if d < best_d
                best_d = d
                best_s = s
            end
        end
        st.state_id[x, y] = best_s
        push!(st.state_patches[best_s], (x, y))
    end

    # Create agents proportional to population
    for i in 1:49
        pop = HIV_STATE_DATA[i][4]
        pct = HIV_STATE_DATA[i][5]
        n_agents = max(1, div(pop, params.pop_scale))
        n_infected = round(Int, n_agents * pct)
        patches = st.state_patches[i]
        isempty(patches) && continue

        for j in 1:n_agents
            px, py = patches[rand(rng, 1:length(patches))]
            is_inf = j <= n_infected
            agent = HIVAgent(px, py, i, is_inf, false, 0,
                             rand(rng, 0:5), false, px, py)
            push!(st.agents, agent)
            push!(st.alive, true)
        end
    end

    _update_hiv_stats!(st, stats)
    return nothing
end

function _update_hiv_stats!(st::HIVState, stats::HIVStats)
    total = 0
    infected = 0
    for i in eachindex(st.agents)
        if st.alive[i]
            total += 1
            if st.agents[i].infected
                infected += 1
            end
        end
    end
    stats.total_agents = total
    stats.total_infected = infected
    stats.pct_infected = total > 0 ? infected / total : 0.0
    return nothing
end

# Ticket-based state lookup
function _ticket_to_state(ticket::Int)
    for i in 1:49
        if HIV_STATE_DATA[i][6] <= ticket <= HIV_STATE_DATA[i][7]
            return i
        end
    end
    return 1
end

# Wrapping helper
function _hiv_wrap(v::Int, sz::Int)
    return mod1(v, sz)
end

# --- Aging & Reproduction ---

struct HIVAgingSystem <: System end

function update!(::HIVAgingSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    st = get_resource(world, HIVState)

    new_agents = HIVAgent[]
    for i in eachindex(st.agents)
        !st.alive[i] && continue
        a = st.agents[i]
        a.age += 1
        if a.age >= 6
            # Reproduce: new agent at same position
            child_inf = a.infected && rand(rng) < 0.01
            push!(new_agents, HIVAgent(a.x, a.y, a.home_state, child_inf,
                                       false, 0, 0, false, a.x, a.y))
            # Uncouple partner
            if a.coupled && a.partner_idx > 0 && a.partner_idx <= length(st.agents) && st.alive[a.partner_idx]
                st.agents[a.partner_idx].coupled = false
                st.agents[a.partner_idx].partner_idx = 0
            end
            st.alive[i] = false
        end
    end

    for na in new_agents
        push!(st.agents, na)
        push!(st.alive, true)
    end
    return nothing
end

# --- Movement ---

struct HIVMovementSystem <: System end

function update!(::HIVMovementSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    st = get_resource(world, HIVState)
    w, h = st.width, st.height

    for i in eachindex(st.agents)
        !st.alive[i] && continue
        a = st.agents[i]

        if rand(rng) < 0.66
            # Long-distance travel
            ticket = rand(rng, 1:1130)
            dest_state = _ticket_to_state(ticket)
            patches = st.state_patches[dest_state]
            if !isempty(patches)
                px, py = patches[rand(rng, 1:length(patches))]
                a.traveling = true
                a.home_x = a.x
                a.home_y = a.y
                a.x = px
                a.y = py
            end
        else
            # Local move within radius 5 in same state
            dx = rand(rng, -5:5)
            dy = rand(rng, -5:5)
            nx = _hiv_wrap(a.x + dx, w)
            ny = _hiv_wrap(a.y + dy, h)
            if st.state_id[nx, ny] == a.home_state
                a.x = nx
                a.y = ny
            end
        end
    end
    return nothing
end

# --- Coupling & Infection ---

struct HIVCouplingSystem <: System end

function update!(::HIVCouplingSystem, world::World)
    params = get_resource(world, HIVParams)
    rng = get_resource(world, RNGResource).rng
    st = get_resource(world, HIVState)
    w, h = st.width, st.height

    inf_rate = params.condom_use ? 0.2 : params.infection_rate

    # Build spatial grid index (cell size 11 covers radius 5 from center)
    cell_sz = 11
    gw = div(w, cell_sz) + 1
    gh = div(h, cell_sz) + 1
    spatial = [Int[] for _ in 1:(gw*gh)]
    n_agents = length(st.agents)
    for i in 1:n_agents
        !st.alive[i] && continue
        a = st.agents[i]
        a.coupled && continue
        cx = div(a.x - 1, cell_sz) + 1
        cy = div(a.y - 1, cell_sz) + 1
        push!(spatial[(cy-1)*gw + cx], i)
    end

    for i in 1:n_agents
        !st.alive[i] && continue
        a = st.agents[i]
        a.coupled && continue

        ax_cell = div(a.x - 1, cell_sz) + 1
        ay_cell = div(a.y - 1, cell_sz) + 1

        found = false
        for dcx in -1:1, dcy in -1:1
            found && break
            ncx = ax_cell + dcx
            ncy = ay_cell + dcy
            (ncx < 1 || ncx > gw || ncy < 1 || ncy > gh) && continue
            cell_agents = spatial[(ncy-1)*gw + ncx]
            for j in cell_agents
                j == i && continue
                !st.alive[j] && continue
                b = st.agents[j]
                b.coupled && continue

                dx = abs(a.x - b.x)
                dy = abs(a.y - b.y)
                dx = min(dx, w - dx)
                dy = min(dy, h - dy)
                if dx <= 5 && dy <= 5
                    a.coupled = true
                    b.coupled = true
                    a.partner_idx = j
                    b.partner_idx = i

                    if a.infected && !b.infected
                        if rand(rng) < inf_rate
                            b.infected = true
                        end
                    elseif b.infected && !a.infected
                        if rand(rng) < inf_rate
                            a.infected = true
                        end
                    end
                    found = true
                    break
                end
            end
        end
    end
    return nothing
end

# --- Return Home ---

struct HIVReturnSystem <: System end

function update!(::HIVReturnSystem, world::World)
    st = get_resource(world, HIVState)
    for i in eachindex(st.agents)
        !st.alive[i] && continue
        a = st.agents[i]
        if a.traveling
            a.x = a.home_x
            a.y = a.home_y
            a.traveling = false
        end
        # Uncouple after each tick
        if a.coupled
            if a.partner_idx > 0 && a.partner_idx <= length(st.agents) && st.alive[a.partner_idx]
                st.agents[a.partner_idx].coupled = false
                st.agents[a.partner_idx].partner_idx = 0
            end
            a.coupled = false
            a.partner_idx = 0
        end
    end
    return nothing
end

# --- Stats ---

struct HIVStatsSystem <: System end

function update!(::HIVStatsSystem, world::World)
    st = get_resource(world, HIVState)
    stats = get_resource(world, HIVStats)
    _update_hiv_stats!(st, stats)
    return nothing
end

# --- Termination ---

struct HIVTerminationSystem <: System end

function update!(::HIVTerminationSystem, world::World)
    params = get_resource(world, HIVParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
