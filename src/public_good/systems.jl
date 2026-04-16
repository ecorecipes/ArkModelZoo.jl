# NetLogo-compatible rounding (round half up, not banker's rounding)
# Use Float64 to avoid Int64 overflow with exponentially growing values
_nl_round(x) = floor(x + 0.5)

# --- Initialization ---

struct InitPGSystem <: System end

function initialize!(::InitPGSystem, world::World)
    params = get_resource(world, PGParams)

    for i in 1:params.num_agents
        ag = PGStudent()
        ag.id = i
        ag.money = params.initial_money
        ag.fraction_put_in = params.fraction_put_in
        ag.investment = 0.0
        new_entity!(world, (ag,))
    end

    _pg_update_stats!(world)
    return nothing
end

# --- Go: take money, multiply, distribute ---
# Each round: agents invest fraction of their money, pool is multiplied,
# then divided equally among all agents.

struct PGGoSystem <: System end

function update!(::PGGoSystem, world::World)
    params = get_resource(world, PGParams)
    rng = get_resource(world, RNGResource).rng
    stats = get_resource(world, PGStats)

    # Collect agents
    agents = PGStudent[]
    eids = Entity[]
    for (e_arr, ag_arr) in Query(world, (PGStudent,))
        for i in eachindex(e_arr)
            push!(eids, e_arr[i])
            push!(agents, ag_arr[i])
        end
    end
    Random.shuffle!(rng, agents)

    n = length(agents)
    n == 0 && return nothing

    # Take money: each agent invests
    bank = 0.0
    for ag in agents
        ag.investment = Float64(_nl_round(ag.fraction_put_in * ag.money))
        bank += ag.investment
        ag.money -= ag.investment
    end

    # Multiply the bank
    bank *= params.multiplier

    # Distribute equally
    share = bank / n
    for ag in agents
        ag.money += share
    end

    # Optional punishment: all agents pay, then richest pays again
    if params.punish
        for ag in agents
            ag.money -= params.punishment_cost
        end
        richest = agents[1]
        for ag in agents
            if ag.money > richest.money
                richest = ag
            end
        end
        richest.money -= params.punishment_cost
    end

    stats.turn += 1
    stats.bank = bank
    _pg_update_stats!(world)
    return nothing
end

function _pg_update_stats!(world::World)
    stats = get_resource(world, PGStats)
    money_total = 0.0
    invest_total = 0.0
    n = 0
    for (_, ag_arr) in Query(world, (PGStudent,))
        for ag in ag_arr
            money_total += ag.money
            invest_total += ag.investment
            n += 1
        end
    end
    if n > 0
        stats.mean_money = money_total / n
        stats.mean_investment = invest_total / n
    end
end

# --- Termination ---

struct PGTerminationSystem <: System end

function update!(::PGTerminationSystem, world::World)
    params = get_resource(world, PGParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
