# --- Constants ---

const _WC_SPAN = 33
const _WC_HALF = 16.5

# --- Helpers ---

function _wc_wrap(v::Float64)
    return mod(v + _WC_HALF, Float64(_WC_SPAN)) - _WC_HALF
end

function _wc_dist(x1::Float64, y1::Float64, x2::Float64, y2::Float64)
    dx = abs(x1 - x2)
    if dx > _WC_HALF
        dx = Float64(_WC_SPAN) - dx
    end
    dy = abs(y1 - y2)
    if dy > _WC_HALF
        dy = Float64(_WC_SPAN) - dy
    end
    return sqrt(dx * dx + dy * dy)
end

function _wc_random_walk!(rng, state::WCState, idx::Int)
    state.heading[idx] = mod(state.heading[idx] + Float64(rand(rng, 0:359)), 360.0)
    θ = deg2rad(state.heading[idx])
    state.x[idx] = _wc_wrap(state.x[idx] + sin(θ))
    state.y[idx] = _wc_wrap(state.y[idx] + cos(θ))
end

function _wc_draw_graphs!(state::WCState, stats::WCStats)
    n = state.n_agents
    n_bel = state.n_believers
    n_dis = state.n_disbelievers

    oi_sum = 0.0
    n_off = 0
    n_inter = 0
    n_neut = 0
    for i in 1:n
        p = state.property[i]
        if p === :offender
            oi_sum += state.offender_index[i]
            n_off += 1
        elseif p === :intervener
            n_inter += 1
        elseif p === :neutralized
            n_neut += 1
        end
    end

    stats.curr_oi = oi_sum / n
    stats.cnt_inter = Float64(n_inter) / Float64(n_dis) * 100.0
    stats.cnt_offenders = Float64(n_off) / Float64(n_bel) * 100.0
    stats.cnt_neutralized = Float64(n_neut) / Float64(n_bel) * 100.0
end

function _wc_applyrules!(state::WCState, params::WCParams, intervener::Int, offender::Int, neighbor_list::Vector{Int})
    m = count(i -> state.perform_intervention[i], neighbor_list)
    n_nbrs = length(neighbor_list)

    # Audience inhibition: if no one else is helping, all neighbors inhibit
    intervention_eval_neg = (m == 0)
    audience_inhibition = intervention_eval_neg ? Float64(n_nbrs) : Float64(n_nbrs - m)

    # Intervention cost
    intervention_cost = Float64(n_nbrs - m)

    # Personal responsibility
    thresh = state.my_thresholds[intervener]
    personal_responsibility = (intervention_cost < thresh && audience_inhibition < thresh)

    # Seriousness (persistent per-agent, updated each evaluation)
    y = Float64(n_nbrs - m)
    if y == 0.0
        y = 0.001
    end
    seriousness = state.seriousness[intervener] / (y ^ params.alpha)
    state.seriousness[intervener] = seriousness

    # Emergency & intention
    emergency = seriousness > params.norm
    intention_help = personal_responsibility && emergency

    # Decision (capability/resources/opportunity always true in this model)
    if intention_help
        state.perform_intervention[intervener] = true
    else
        state.perform_intervention[intervener] = false
        if params.incorporate_guilt
            guilt = Float64(params.crime_intensity) - (Float64(m) / Float64(n_nbrs))
            state.my_thresholds[intervener] += guilt
        end
    end

    # Effect on offender
    if state.perform_intervention[intervener]
        state.offender_index[offender] -= Float64(m) / Float64(params.crime_intensity)
        if state.offender_index[offender] <= 0.0
            state.property[offender] = :neutralized
        end
    end
end

function _wc_vd!(rng, state::WCState, params::WCParams)
    # Iterate over offenders in random order (NetLogo ask shuffle)
    offenders = [i for i in 1:state.n_agents if state.property[i] === :offender]
    shuffle!(rng, offenders)

    for off in offenders
        if state.offender_index[off] <= 0.0
            continue
        end

        # Find non-offenders within radius with complying_for < crime_intensity
        ox, oy = state.x[off], state.y[off]
        in_range = Int[]
        for i in 1:state.n_agents
            if i != off &&
               state.property[i] !== :offender &&
               state.complying_for[i] < params.crime_intensity &&
               _wc_dist(ox, oy, state.x[i], state.y[i]) <= params.radius
                push!(in_range, i)
            end
        end

        if !isempty(in_range)
            interv = in_range[rand(rng, 1:length(in_range))]
            state.property[interv] = :intervener

            # Neighbor-list: non-offenders within radius of the INTERVENER (includes self)
            ix, iy = state.x[interv], state.y[interv]
            nbrs = Int[]
            for i in 1:state.n_agents
                if state.property[i] !== :offender &&
                   _wc_dist(ix, iy, state.x[i], state.y[i]) <= params.radius
                    push!(nbrs, i)
                end
            end

            _wc_applyrules!(state, params, interv, off, nbrs)
        end
    end
end

# --- Systems ---

struct InitWCSystem <: System end

function initialize!(::InitWCSystem, world::World)
    params = get_resource(world, WCParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, WCState)
    stats = get_resource(world, WCStats)

    n_patches = _WC_SPAN * _WC_SPAN
    total = div(params.population * n_patches, 100)
    n_bel = div(total * params.tb_perc, 100)
    n_dis = total - n_bel
    n = n_bel + n_dis

    state.n_agents = n
    state.n_believers = n_bel
    state.n_disbelievers = n_dis

    # Place agents at unique patches (shuffle all coordinates, take first n)
    patches = [(x, y) for x in -16:16 for y in -16:16]
    shuffle!(rng, patches)

    state.x = [Float64(patches[i][1]) for i in 1:n]
    state.y = [Float64(patches[i][2]) for i in 1:n]
    state.heading = zeros(Float64, n)
    state.belief = zeros(Int, n)
    state.compliance = zeros(Int, n)
    state.strength = zeros(Float64, n)
    state.complying_for = zeros(Int, n)
    state.property = fill(:bystanders, n)
    state.offender_index = zeros(Float64, n)
    state.perform_intervention = falses(n)
    state.my_thresholds = zeros(Float64, n)
    state.seriousness = fill(Float64(params.crime_intensity) / 3.0, n)

    # Believers (indices 1..n_bel)
    for i in 1:n_bel
        state.heading[i] = 0.0
        state.belief[i] = 1
        state.compliance[i] = 1
        state.strength[i] = 1.0
        state.property[i] = :offender
        state.offender_index[i] = 1.0
    end

    # Disbelievers (indices n_bel+1..n)
    for i in (n_bel + 1):n
        state.heading[i] = 180.0
        state.belief[i] = -1
        state.compliance[i] = -1
        state.strength[i] = rand(rng) * 0.3
        state.my_thresholds[i] = params.threshold
    end

    _wc_draw_graphs!(state, stats)
    return nothing
end

struct WCGoSystem <: System end

function update!(::WCGoSystem, world::World)
    params = get_resource(world, WCParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, WCState)
    stats = get_resource(world, WCStats)

    # Gerritsen model: reportdata (no-op) → VD → draw-graphs → random-walk
    _wc_vd!(rng, state, params)
    _wc_draw_graphs!(state, stats)

    if params.mobility
        for i in 1:state.n_agents
            _wc_random_walk!(rng, state, i)
        end
    end

    return nothing
end

struct WCTerminationSystem <: System end

function update!(::WCTerminationSystem, world::World)
    params = get_resource(world, WCParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
