# --- Helpers ---

function _pareto_expected_utility(n::Matrix{Int}, payoff::Matrix{Int}, my_action::Int)
    ni = n[my_action, 1] + n[my_action, 2]
    eu = 0.0
    for a in 1:2
        eu += payoff[my_action, a] * n[my_action, a] / ni
    end
    return eu
end

function _pareto_take_action(n::Matrix{Int}, payoff::Matrix{Int},
                             epsilon::Float64, tick::Int,
                             random_ticks::Int, rng)
    if tick < random_ticks
        return rand(rng, 1:2)
    else
        eu1 = _pareto_expected_utility(n, payoff, 1)
        eu2 = _pareto_expected_utility(n, payoff, 2)
        best = eu1 >= eu2 ? 1 : 2
        if rand(rng) < 1.0 - epsilon
            return best
        else
            return 3 - best
        end
    end
end

# --- Initialization ---

struct InitParetoLearnSystem <: System end

function initialize!(::InitParetoLearnSystem, world::World)
    params = get_resource(world, ParetoLearnParams)
    state = get_resource(world, ParetoLearnerState)
    stats = get_resource(world, ParetoStats)

    state.epsilon = params.exploration_rate
    for i in 1:2
        state.n[i] .= 1
        state.actions[i] = 0
    end

    # Initial EU from learner 1's perspective
    stats.eu_cooperate = _pareto_expected_utility(state.n[1], params.payoff, 1)
    stats.eu_defect = _pareto_expected_utility(state.n[1], params.payoff, 2)
    return nothing
end

# --- Update ---

struct ParetoLearnUpdateSystem <: System end

function update!(::ParetoLearnUpdateSystem, world::World)
    params = get_resource(world, ParetoLearnParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, ParetoLearnerState)
    stats = get_resource(world, ParetoStats)
    tick_val = get_resource(world, Tick).tick

    # ask learners [take-action] — random order
    order = randperm(rng, 2)
    for i in order
        state.actions[i] = _pareto_take_action(
            state.n[i], params.payoff, state.epsilon,
            tick_val, params.random_ticks, rng,
        )
    end

    # ask learners [adapt] — random order
    order = randperm(rng, 2)
    for i in order
        other = 3 - i
        my_action = state.actions[i]
        his_action = state.actions[other]
        state.n[i][my_action, his_action] += 1
    end

    # ask learner 0 [set eu-cooperate ...; set eu-defect ...]
    stats.eu_cooperate = _pareto_expected_utility(state.n[1], params.payoff, 1)
    stats.eu_defect = _pareto_expected_utility(state.n[1], params.payoff, 2)
    return nothing
end

# --- Termination ---

struct ParetoLearnTerminationSystem <: System end

function update!(::ParetoLearnTerminationSystem, world::World)
    params = get_resource(world, ParetoLearnParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
