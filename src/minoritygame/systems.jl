# --- Initialization ---

struct InitMGSystem <: System end

function initialize!(::InitMGSystem, world::World)
    params = get_resource(world, MGParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, MGState)
    mem = params.memory
    strat_len = 2^mem

    state.history = rand(rng, 0:(strat_len - 1))

    for _ in 1:params.number
        agent = MGAgent()
        agent.score = 0
        agent.strategies_scores = zeros(Int, params.strategies_per_agent)

        # Assign unique strategies
        strats = Set{Vector{Int}}()
        while length(strats) < params.strategies_per_agent
            s = [rand(rng, 0:1) for _ in 1:strat_len]
            push!(strats, s)
        end
        agent.strategies = collect(strats)
        agent.current_strategy = rand(rng, 1:params.strategies_per_agent)
        agent.choice = agent.strategies[agent.current_strategy][state.history + 1]
        new_entity!(world, (agent,))
    end

    # Update system state
    _mg_update_system!(world)
    return nothing
end

function _mg_update_system!(world::World)
    params = get_resource(world, MGParams)
    state = get_resource(world, MGState)
    stats = get_resource(world, MGStats)

    num_zero = 0
    scores = Float64[]
    for (_, agents) in Query(world, (MGAgent,))
        @inbounds for i in eachindex(agents)
            a = agents[i]
            if a.choice == 0
                num_zero += 1
            end
            push!(scores, Float64(a.score))
        end
    end

    state.num_picking_zero = num_zero
    state.minority = num_zero <= (params.number - 1) ÷ 2 ? 0 : 1
    state.avg_score = length(scores) > 0 ? Statistics.mean(scores) : 0.0
    state.stdev_score = length(scores) > 1 ? Statistics.std(scores) : 0.0

    stats.avg_score = state.avg_score
    stats.stdev_score = state.stdev_score
    stats.num_picking_zero = num_zero
end

# --- Go ---

struct MGGoSystem <: System end

function update!(::MGGoSystem, world::World)
    params = get_resource(world, MGParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, MGState)
    mem = params.memory

    # Update scores and strategy for each agent
    for (_, agents) in Query(world, (MGAgent,))
        @inbounds for i in eachindex(agents)
            a = agents[i]
            # Increment virtual scores
            for s_idx in 1:length(a.strategies)
                if a.strategies[s_idx][state.history + 1] == state.minority
                    a.strategies_scores[s_idx] += 1
                end
            end
            # Pick best strategy
            max_score = maximum(a.strategies_scores)
            best = [j for j in 1:length(a.strategies_scores) if a.strategies_scores[j] == max_score]
            a.current_strategy = best[rand(rng, 1:length(best))]
            # Update own score
            if a.choice == state.minority
                a.score += 1
            end
        end
    end

    # Update history: shift left, append minority
    full_hist = _mg_full_history(state.history, mem)
    push!(full_hist, state.minority)
    popfirst!(full_hist)
    state.history = _mg_decimal(full_hist)

    # Update choices
    for (_, agents) in Query(world, (MGAgent,))
        @inbounds for i in eachindex(agents)
            a = agents[i]
            a.choice = a.strategies[a.current_strategy][state.history + 1]
        end
    end

    _mg_update_system!(world)
    return nothing
end

function _mg_full_history(hist::Int, mem::Int)
    bits = Int[]
    h = hist
    for _ in 1:mem
        pushfirst!(bits, h & 1)
        h >>= 1
    end
    return bits
end

function _mg_decimal(bits::Vector{Int})
    result = 0
    for b in bits
        result = 2 * result + b
    end
    return result
end

# --- Termination ---

struct MGTerminationSystem <: System end

function update!(::MGTerminationSystem, world::World)
    params = get_resource(world, MGParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
