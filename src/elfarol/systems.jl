# --- Helpers ---

# NetLogo: 1.0 - random-float 2.0 → values in (-1.0, 1.0]
function _elfarol_random_strategy(rng, memory_size::Int)
    return [1.0 - rand(rng) * 2.0 for _ in 1:(memory_size + 1)]
end

# NetLogo: 100 * first strategy + sum(map ... butfirst strategy subhistory)
function _elfarol_predict(strategy::Vector{Float64}, subhistory::AbstractVector{Int})
    pred = 100.0 * strategy[1]
    for i in eachindex(subhistory)
        pred += strategy[i + 1] * subhistory[i]
    end
    return pred
end

# Evaluate all strategies against history, pick the one with lowest total error.
# NetLogo: if score <= best-score ⇒ ties broken by LAST strategy.
function _elfarol_update_best!(strats::ElFarolStrategies, history::Vector{Int}, memory_size::Int)
    best_score = memory_size * 100.0 + 1.0
    for s in strats.strategies
        score = 0.0
        for week in 1:memory_size
            pred = _elfarol_predict(s, @view history[(week + 1):(week + memory_size)])
            score += abs(history[week] - pred)
        end
        if score <= best_score
            best_score = score
            strats.best_strategy = s
        end
    end
end

# --- Initialization ---

struct InitElFarolSystem <: System end

function initialize!(::InitElFarolSystem, world::World)
    params = get_resource(world, ElFarolParams)
    rng = get_resource(world, RNGResource).rng
    hist = get_resource(world, ElFarolHistory)
    stats = get_resource(world, ElFarolStats)

    # history: n-values (memory-size * 2) [random 100]  (most-recent first)
    hist.history = [rand(rng, 0:99) for _ in 1:(params.memory_size * 2)]
    stats.attendance = first(hist.history)

    for _ in 1:params.num_agents
        strategies = [_elfarol_random_strategy(rng, params.memory_size)
                      for _ in 1:params.number_strategies]
        new_entity!(world, (
            ElFarolStrategies(strategies, strategies[1]),
            ElFarolDecision(false, 0.0),
        ))
    end

    # NetLogo calls update-strategies in create-turtles block
    for (_, sv) in Query(world, (ElFarolStrategies,))
        @inbounds for i in eachindex(sv)
            _elfarol_update_best!(sv[i], hist.history, params.memory_size)
        end
    end
    return nothing
end

# --- Update (go) ---

struct ElFarolUpdateSystem <: System end

function update!(::ElFarolUpdateSystem, world::World)
    params = get_resource(world, ElFarolParams)
    hist = get_resource(world, ElFarolHistory)
    stats = get_resource(world, ElFarolStats)
    ms = params.memory_size

    # 1. Predict & decide (independent — order irrelevant)
    for (_, sv, dv) in Query(world, (ElFarolStrategies, ElFarolDecision))
        @inbounds for i in eachindex(sv)
            pred = _elfarol_predict(sv[i].best_strategy, @view hist.history[1:ms])
            dv[i].prediction = pred
            dv[i].attend = (pred <= params.overcrowding_threshold)
        end
    end

    # 2. Count attendance
    attendance = 0
    for (_, dv) in Query(world, (ElFarolDecision,))
        @inbounds for i in eachindex(dv)
            attendance += dv[i].attend
        end
    end
    stats.attendance = attendance

    # 3. Update history: fput attendance but-last history
    pop!(hist.history)                       # drop oldest (last element)
    pushfirst!(hist.history, attendance)      # prepend newest

    # 4. Update strategies
    for (_, sv) in Query(world, (ElFarolStrategies,))
        @inbounds for i in eachindex(sv)
            _elfarol_update_best!(sv[i], hist.history, ms)
        end
    end
    return nothing
end

# --- Stats (attendance already tracked in update) ---

struct ElFarolStatsSystem <: System end
function update!(::ElFarolStatsSystem, world::World)
    return nothing
end

# --- Termination ---

struct ElFarolTerminationSystem <: System end

function update!(::ElFarolTerminationSystem, world::World)
    params = get_resource(world, ElFarolParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
