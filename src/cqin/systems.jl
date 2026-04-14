struct InitCQINSystem <: System end

function _cqin_build_pa!(net::CQINNetwork, rng, n::Int, m::Int)
    # Build preferential-attachment network (Barabási-Albert)
    # Start with m+1 fully connected nodes
    for _ in 1:(m+1)
        _cqin_add_node!(net, CQIN_SUSCEPTIBLE)
    end
    for i in 1:(m+1), j in (i+1):(m+1)
        _cqin_add_edge!(net, i, j)
    end
    # Add remaining nodes with preferential attachment
    for _ in (m+2):n
        new_id = _cqin_add_node!(net, CQIN_SUSCEPTIBLE)
        total_degree = sum(net.degree[1:new_id-1])
        targets = Set{Int}()
        attempts = 0
        while length(targets) < m && attempts < 10000
            attempts += 1
            r = rand(rng) * total_degree
            cumulative = 0.0
            for j in 1:(new_id-1)
                cumulative += net.degree[j]
                if cumulative >= r
                    push!(targets, j)
                    break
                end
            end
        end
        for t in targets
            _cqin_add_edge!(net, new_id, t)
        end
    end
end

function initialize!(::InitCQINSystem, world::World)
    params = get_resource(world, CQINParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, CQINNetwork)
    stats = get_resource(world, CQINStats)

    _cqin_build_pa!(net, rng, params.number_of_nodes, params.node_degree)
    net.signal = params.signal_base

    # Run initial cycle
    _cqin_cycle!(net, rng, params)
    _cqin_update_counts!(net, stats)
    return nothing
end

function _cqin_cycle!(net::CQINNetwork, rng, params::CQINParams)
    # Reset all nodes to susceptible, reset timers
    for i in 1:net.n_nodes
        net.states[i] = CQIN_SUSCEPTIBLE
        net.schema_check_timer[i] = 0
    end
    net.iteration_count += 1
    # Pick initial_detection_size random nodes → set to UPDATED
    indices = shuffle!(rng, collect(1:net.n_nodes))
    for k in 1:min(params.initial_detection_size, net.n_nodes)
        net.states[indices[k]] = CQIN_UPDATED
    end
end

# Check whether any stop condition is met
function _cqin_should_stop(net::CQINNetwork, params::CQINParams, target_state::Int)
    n_resistant = count(==(CQIN_RESISTANT), net.states)
    if n_resistant >= net.n_nodes * params.max_non_cooperating
        return true
    end
    # All nodes are in target state or resistant
    if all(s -> s == target_state || s == CQIN_RESISTANT, net.states)
        return true
    end
    if net.iteration_count == params.planned_iterations + 1
        return true
    end
    if net.signal >= params.signal_target
        return true
    end
    return false
end

# Schema check: node may become resistant or advance to next_state
function _cqin_schema_check!(net::CQINNetwork, rng, params::CQINParams, i::Int, current_state::Int, next_state::Int)
    complexity = params.problem_space_complexity
    threshold_mod = params.rejection_threshold * (0.8 + complexity / 100.0)
    chance_mod = params.rejection_chance * (0.8 + complexity / 100.0)
    if rand(rng) * 100.0 < threshold_mod
        if rand(rng) * 100.0 < chance_mod
            net.states[i] = CQIN_RESISTANT
        else
            net.states[i] = next_state
        end
    end
end

# Phase 1: spread-signal (updated nodes spread to susceptible neighbors)
function _cqin_phase1!(net::CQINNetwork, rng, params::CQINParams)
    effectiveness = params.schema_share_effectiveness * params.learning_gain ^ net.iteration_count
    order = shuffle!(rng, collect(1:net.n_nodes))
    for i in order
        net.states[i] == CQIN_UPDATED || continue
        net.schema_check_timer[i] += 1
        neighbors = shuffle!(rng, collect(net.adj[i]))
        for j in neighbors
            if net.states[j] == CQIN_SUSCEPTIBLE
                if rand(rng) * 100.0 < effectiveness
                    net.states[j] = CQIN_UPDATED
                end
            end
        end
    end
    # Schema checks for updated nodes
    order2 = shuffle!(rng, collect(1:net.n_nodes))
    for i in order2
        net.states[i] == CQIN_UPDATED || continue
        if net.schema_check_timer[i] > 0 && mod(net.schema_check_timer[i], params.schema_check_frequency) == 0
            _cqin_schema_check!(net, rng, params, i, CQIN_UPDATED, CQIN_AGREED)
        end
    end
end

# Phase 2: problem-solve (updated → agreed spread)
function _cqin_phase2!(net::CQINNetwork, rng, params::CQINParams)
    effectiveness = params.schema_share_effectiveness * params.learning_gain ^ net.iteration_count
    ps_factor = (params.problem_solving_effectiveness * params.learning_gain ^ net.iteration_count) / params.problem_space_complexity
    prob = effectiveness * ps_factor
    order = shuffle!(rng, collect(1:net.n_nodes))
    for i in order
        net.states[i] == CQIN_AGREED || continue
        net.schema_check_timer[i] += 1
        neighbors = shuffle!(rng, collect(net.adj[i]))
        for j in neighbors
            if net.states[j] == CQIN_UPDATED
                if rand(rng) * 100.0 < prob
                    net.states[j] = CQIN_AGREED
                end
            end
        end
    end
    # Schema checks for agreed nodes
    order2 = shuffle!(rng, collect(1:net.n_nodes))
    for i in order2
        net.states[i] == CQIN_AGREED || continue
        if net.schema_check_timer[i] > 0 && mod(net.schema_check_timer[i], params.schema_check_frequency) == 0
            _cqin_schema_check!(net, rng, params, i, CQIN_AGREED, CQIN_IMPLEMENTED)
        end
    end
end

# Phase 3: implement (agreed → implemented spread)
function _cqin_phase3!(net::CQINNetwork, rng, params::CQINParams)
    effectiveness = params.schema_share_effectiveness * params.learning_gain ^ net.iteration_count
    ps_factor = (params.problem_solving_effectiveness * params.learning_gain ^ net.iteration_count) / params.problem_space_complexity
    coev_factor = (100.0 - params.coevolution_constraints) / 100.0
    prob = effectiveness * ps_factor * coev_factor
    order = shuffle!(rng, collect(1:net.n_nodes))
    for i in order
        net.states[i] == CQIN_IMPLEMENTED || continue
        net.schema_check_timer[i] += 1
        neighbors = shuffle!(rng, collect(net.adj[i]))
        for j in neighbors
            if net.states[j] == CQIN_AGREED
                if rand(rng) * 100.0 < prob
                    net.states[j] = CQIN_IMPLEMENTED
                end
            end
        end
    end
    # Schema checks for implemented nodes
    order2 = shuffle!(rng, collect(1:net.n_nodes))
    for i in order2
        net.states[i] == CQIN_IMPLEMENTED || continue
        if net.schema_check_timer[i] > 0 && mod(net.schema_check_timer[i], params.schema_check_frequency) == 0
            _cqin_schema_check!(net, rng, params, i, CQIN_IMPLEMENTED, CQIN_REVIEWED)
        end
    end
end

# Phase 4: review (implemented → reviewed spread)
function _cqin_phase4!(net::CQINNetwork, rng, params::CQINParams)
    effectiveness = params.schema_share_effectiveness * params.learning_gain ^ net.iteration_count
    order = shuffle!(rng, collect(1:net.n_nodes))
    for i in order
        net.states[i] == CQIN_REVIEWED || continue
        net.schema_check_timer[i] += 1
        neighbors = shuffle!(rng, collect(net.adj[i]))
        for j in neighbors
            if net.states[j] == CQIN_IMPLEMENTED
                if rand(rng) * 100.0 < effectiveness
                    net.states[j] = CQIN_REVIEWED
                end
            end
        end
    end
    # Schema checks for reviewed nodes
    order2 = shuffle!(rng, collect(1:net.n_nodes))
    for i in order2
        net.states[i] == CQIN_REVIEWED || continue
        if net.schema_check_timer[i] > 0 && mod(net.schema_check_timer[i], params.schema_check_frequency) == 0
            _cqin_schema_check!(net, rng, params, i, CQIN_REVIEWED, CQIN_ADJUSTED)
        end
    end
end

# Phase 5: adjust (reviewed → adjusted spread, update signal)
function _cqin_phase5!(net::CQINNetwork, rng, params::CQINParams)
    effectiveness = params.schema_share_effectiveness * params.learning_gain ^ net.iteration_count
    ps_factor = (params.problem_solving_effectiveness * params.learning_gain ^ net.iteration_count) / params.problem_space_complexity
    coev_factor = (100.0 - params.coevolution_constraints) / 100.0
    prob = effectiveness * ps_factor * coev_factor
    order = shuffle!(rng, collect(1:net.n_nodes))
    for i in order
        net.states[i] == CQIN_ADJUSTED || continue
        net.schema_check_timer[i] += 1
        neighbors = shuffle!(rng, collect(net.adj[i]))
        for j in neighbors
            if net.states[j] == CQIN_REVIEWED
                if rand(rng) * 100.0 < prob
                    net.states[j] = CQIN_ADJUSTED
                end
            end
        end
    end
    # Schema checks for adjusted nodes — also update signal
    order2 = shuffle!(rng, collect(1:net.n_nodes))
    for i in order2
        net.states[i] == CQIN_ADJUSTED || continue
        if net.schema_check_timer[i] > 0 && mod(net.schema_check_timer[i], params.schema_check_frequency) == 0
            _cqin_schema_check!(net, rng, params, i, CQIN_ADJUSTED, CQIN_ADJUSTED)
            # Signal update after schema check in phase 5
            if net.states[i] == CQIN_ADJUSTED
                net.signal = min(net.signal + params.signal_increment, params.signal_target)
            end
        end
    end
end

struct CQINGoSystem <: System end

function update!(::CQINGoSystem, world::World)
    params = get_resource(world, CQINParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, CQINNetwork)
    stats = get_resource(world, CQINStats)

    # Each tick is one full PDSA cycle: cycle → 5×phase1 → 5×phase2 → 5×phase3 → 5×phase4 → 5×phase5
    _cqin_cycle!(net, rng, params)

    # Phase 1: spread-signal (go), repeat 5
    for _ in 1:5
        _cqin_should_stop(net, params, CQIN_UPDATED) && break
        _cqin_phase1!(net, rng, params)
    end

    # Phase 2: problem-solve (go-2), repeat 5
    for _ in 1:5
        _cqin_should_stop(net, params, CQIN_AGREED) && break
        _cqin_phase2!(net, rng, params)
    end

    # Phase 3: implement (go-3), repeat 5
    for _ in 1:5
        _cqin_should_stop(net, params, CQIN_IMPLEMENTED) && break
        _cqin_phase3!(net, rng, params)
    end

    # Phase 4: review (go-4), repeat 5
    for _ in 1:5
        _cqin_should_stop(net, params, CQIN_REVIEWED) && break
        _cqin_phase4!(net, rng, params)
    end

    # Phase 5: adjust (go-5), repeat 5
    for _ in 1:5
        _cqin_should_stop(net, params, CQIN_ADJUSTED) && break
        _cqin_phase5!(net, rng, params)
    end

    _cqin_update_counts!(net, stats)
    return nothing
end

struct CQINTerminationSystem <: System end

function update!(::CQINTerminationSystem, world::World)
    params = get_resource(world, CQINParams)
    tick = get_resource(world, Tick)
    net = get_resource(world, CQINNetwork)
    if tick.tick + 1 >= params.max_ticks || net.signal >= params.signal_target || net.iteration_count >= params.planned_iterations + 1
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
