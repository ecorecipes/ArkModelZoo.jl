# --- Helpers ---

"""Day utility: x * exp(-x/3)"""
function day_utility(x::Real)
    return x * exp(-x / 3.0)
end

"""Global utility = sum of day_utility over 7 days."""
function global_utility(attendance::AbstractVector)
    s = 0.0
    @inbounds for i in 1:7
        s += day_utility(attendance[i])
    end
    return s
end

"""Weighted stochastic choice: returns 1-indexed action."""
function stochastic_choice(rng, weights::AbstractVector{Float64})
    total = 0.0
    @inbounds for w in weights
        total += w
    end
    r = rand(rng) * total
    cumulative = 0.0
    @inbounds for i in eachindex(weights)
        cumulative += weights[i]
        if r < cumulative
            return i
        end
    end
    return length(weights)
end

# --- Recompute attendance from all agents ---

function recompute_attendance!(world::World, state::CoinState)
    fill!(state.attendance, 0)
    for (_, agents) in Query(world, (CoinAgent,))
        @inbounds for i in eachindex(agents)
            a = agents[i].last_action
            if a >= 1 && a <= 7
                state.attendance[a] += 1
            end
        end
    end
    return nothing
end

# --- Recompute Wonderful Life rewards ---

function recompute_rewards!(state::CoinState)
    g_actual = global_utility(state.attendance)
    state.current_utility = g_actual
    cf = zeros(Float64, 7)
    @inbounds for day in 1:7
        # Counterfactual: remove one agent from day `day`, distribute 1/7 to each day
        for j in 1:7
            cf[j] = state.attendance[j] + 1.0 / 7.0
        end
        cf[day] -= 1.0  # remove the agent from this day (net: -1 + 1/7 = -6/7)
        g_cf = global_utility(cf)
        state.rewards[day] = 1.0 + g_actual - g_cf
    end
    return nothing
end

# --- Learning: decay utilities and reinforce chosen action ---

function learn_agents!(world::World, params::CoinParams, state::CoinState)
    dr = params.discount_rate
    for (_, agents) in Query(world, (CoinAgent,))
        @inbounds for i in eachindex(agents)
            agent = agents[i]
            for j in 1:7
                agent.u[j] *= dr
            end
            a = agent.last_action
            if a >= 1 && a <= 7
                agent.u[a] += state.rewards[a]
            end
        end
    end
    return nothing
end

# --- Initialization ---

struct InitCoinSystem <: System end

function initialize!(::InitCoinSystem, world::World)
    params = get_resource(world, CoinParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, CoinState)

    # Create agents
    for _ in 1:params.num_agents
        new_entity!(world, (CoinAgent(),))
    end

    # Warmup phase: random actions → recompute → learn
    for _ in 1:params.warmup
        # Random actions
        for (_, agents) in Query(world, (CoinAgent,))
            @inbounds for i in eachindex(agents)
                agents[i].last_action = rand(rng, 1:7)
            end
        end
        recompute_attendance!(world, state)
        recompute_rewards!(state)
        learn_agents!(world, params, state)
    end

    # Final attendance and utility after warmup
    recompute_attendance!(world, state)
    state.current_utility = global_utility(state.attendance)
    return nothing
end

# --- Main tick: action → recompute → learn ---

struct CoinActionSystem <: System end

function update!(::CoinActionSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    for (_, agents) in Query(world, (CoinAgent,))
        @inbounds for i in eachindex(agents)
            agents[i].last_action = stochastic_choice(rng, agents[i].u)
        end
    end
    return nothing
end

struct CoinRecomputeSystem <: System end

function update!(::CoinRecomputeSystem, world::World)
    state = get_resource(world, CoinState)
    params = get_resource(world, CoinParams)
    recompute_attendance!(world, state)
    recompute_rewards!(state)
    learn_agents!(world, params, state)
    return nothing
end

# --- Termination ---

struct CoinTerminationSystem <: System end

function update!(::CoinTerminationSystem, world::World)
    params = get_resource(world, CoinParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
