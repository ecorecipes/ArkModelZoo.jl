# --- Helpers ---

function _cl_weighted_one_of(rng, weights::Vector{Float64}, indices::Vector{Int})
    total = 0.0
    for idx in indices
        total += weights[idx]
    end
    total <= 0.0 && return 0
    r = rand(rng) * total
    cumul = 0.0
    for idx in indices
        cumul += weights[idx]
        if r <= cumul
            return idx
        end
    end
    return indices[end]
end

function _cl_compete!(state::CLState, i::Int, j::Int, base_learn::Float64, partner_learn::Float64)
    state.played[i] = true
    state.played[j] = true
    state.plays[i] += 1
    state.plays[j] += 1

    strategy_i = state.strategy[i]
    strategy_j = state.strategy[j]

    # Both players learn from base learning
    state.strategy[i] += (1.0 - state.strategy[i]) * base_learn
    state.strategy[j] += (1.0 - state.strategy[j]) * base_learn

    # Winner/loser partner learning
    if strategy_i > strategy_j
        state.wins[i] += 1
        state.strategy[j] += (strategy_i - strategy_j) * partner_learn
    elseif strategy_j > strategy_i
        state.wins[j] += 1
        state.strategy[i] += (strategy_j - strategy_i) * partner_learn
    end

    # Track plays before reaching 0.99
    if state.strategy[i] < 0.99
        state.plays_to_99[i] += 1
    end
    if state.strategy[j] < 0.99
        state.plays_to_99[j] += 1
    end
    return nothing
end

function _cl_update_stats!(state::CLState, stats::CLStats)
    stats.mean_strategy = sum(state.strategy) / state.n_agents
    stats.min_strategy = minimum(state.strategy)
    return nothing
end

# --- Systems ---

struct InitCLSystem <: System end

function initialize!(::InitCLSystem, world::World)
    params = get_resource(world, CLParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, CLState)
    stats = get_resource(world, CLStats)

    _cl_init_agents!(state, params.num_nodes, rng, params.start_strat_max, params.start_wt)
    _cl_update_stats!(state, stats)
    return nothing
end

struct CLGoSystem <: System end

function update!(::CLGoSystem, world::World)
    params = get_resource(world, CLParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, CLState)
    stats = get_resource(world, CLStats)
    n = state.n_agents

    # Pick one unplayed turtle (NetLogo ask one-of shuffles)
    unplayed = [i for i in 1:n if !state.played[i]]
    length(unplayed) < 2 && return nothing
    player1 = unplayed[rand(rng, 1:length(unplayed))]

    # Find eligible opponents (unplayed neighbors, i.e. all other unplayed agents)
    eligible = [j for j in 1:n if j != player1 && !state.played[j]]
    if !isempty(eligible)
        # Weighted selection by matches_for_choosing
        weights = [state.matches_for_choosing[player1, j] for j in eligible]
        player2 = eligible[_cl_weighted_one_of(rng, weights, collect(1:length(eligible)))]

        # Update match link
        state.matches_for_choosing[player1, player2] += params.match_wt
        state.matches_for_choosing[player2, player1] += params.match_wt
        state.matches_real[player1, player2] += 1.0
        state.matches_real[player2, player1] += 1.0

        _cl_compete!(state, player1, player2, params.base_learn, params.partner_learn)
    end

    # Check if round is over (fewer than 2 unplayed)
    unplayed_count = count(!, state.played)
    if unplayed_count < 2
        for i in 1:n
            state.played[i] = false
        end
        _cl_update_stats!(state, stats)
    end

    # Check termination: min strategy >= 0.999
    if minimum(state.strategy) >= 0.999
        _cl_update_stats!(state, stats)
        get_resource(world, Terminate).stop = true
    end

    return nothing
end

struct CLTerminationSystem <: System end

function update!(::CLTerminationSystem, world::World)
    params = get_resource(world, CLParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
