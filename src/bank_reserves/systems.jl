# --- Initialization ---
struct InitBRESSystem <: System end

function initialize!(::InitBRESSystem, world::World)
    params = get_resource(world, BRESParams)
    rng = get_resource(world, RNGResource).rng

    for _ in 1:params.people
        x = rand(rng, 1:params.grid_width)
        y = rand(rng, 1:params.grid_height)
        wallet = Float64(rand(rng, 1:params.rich_threshold))
        new_entity!(world, (
            BRESPosition(x, y),
            BRESAccount(0.0, 0.0, wallet, 0.0),
        ))
    end

    _bres_bank_balance_sheet!(world)
    _bres_update_stats!(world)
    return nothing
end

# --- Go System ---
struct BRESGoSystem <: System end

function update!(::BRESGoSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    bank = get_resource(world, BRESBank)
    tick = get_resource(world, Tick).tick

    _bres_update_stats!(world)

    # Collect and shuffle agents (NetLogo ask shuffles each tick)
    agent_eids = Entity[]
    for (eids, _, _) in Query(world, (BRESPosition, BRESAccount))
        append!(agent_eids, eids)
    end
    Random.shuffle!(rng, agent_eids)

    phase = tick % 3
    if phase == 0
        _bres_do_business!(world, rng, agent_eids, bank)
    elseif phase == 1
        _bres_balance_books!(world, agent_eids, bank)
    else
        _bres_bank_balance_sheet!(world)
    end
    return nothing
end

# --- Phase 0: do-business ---

function _bres_do_business!(world, rng, agent_eids, bank)
    params = get_resource(world, BRESParams)
    w, h = params.grid_width, params.grid_height
    for eid in agent_eids
        pos, acc = get_components(world, eid, (BRESPosition, BRESAccount))
        # Move: rt random-float 360; fd 1
        heading = rand(rng) * 360.0
        θ = deg2rad(heading)
        pos.x = mod1(round(Int, pos.x + sin(θ)), w)
        pos.y = mod1(round(Int, pos.y + cos(θ)), h)

        if acc.savings > 0 || acc.wallet > 0 || bank.bank_to_loan > 0
            # one-of other turtles-here
            customer_eid = _bres_find_customer(world, eid, pos.x, pos.y, rng)
            if !is_zero(customer_eid)
                if rand(rng, 0:1) == 0  # 50% chance to trade
                    customer_acc = get_components(world, customer_eid, (BRESAccount,))[1]
                    if rand(rng, 0:1) == 0
                        customer_acc.wallet += 5.0
                        acc.wallet -= 5.0
                    else
                        customer_acc.wallet += 2.0
                        acc.wallet -= 2.0
                    end
                end
            end
        end
    end
end

function _bres_find_customer(world, self_eid, x, y, rng)
    candidates = Entity[]
    for (eids, positions, _) in Query(world, (BRESPosition, BRESAccount))
        @inbounds for i in eachindex(positions)
            if positions[i].x == x && positions[i].y == y && eids[i] != self_eid
                push!(candidates, eids[i])
            end
        end
    end
    isempty(candidates) && return zero_entity
    return candidates[rand(rng, 1:length(candidates))]
end

# --- Phase 1: balance-books ---

function _bres_balance_books!(world, agent_eids, bank)
    for eid in agent_eids
        acc = get_components(world, eid, (BRESAccount,))[1]

        if acc.wallet < 0.0
            deficit = -acc.wallet
            if acc.savings >= deficit
                acc.savings -= deficit
                acc.wallet = 0.0
            else
                # Use all savings first, then try loan for remainder
                remaining = deficit - acc.savings
                acc.wallet += acc.savings
                acc.savings = 0.0
                if bank.bank_to_loan >= remaining
                    acc.loans += remaining
                    acc.wallet = 0.0
                    bank.bank_to_loan -= remaining
                elseif bank.bank_to_loan > 0.0
                    acc.loans += bank.bank_to_loan
                    acc.wallet += bank.bank_to_loan
                    bank.bank_to_loan = 0.0
                end
            end
        elseif acc.wallet > 0.0
            acc.savings += acc.wallet
            acc.wallet = 0.0
        end

        # Pay off loans from savings
        if acc.loans > 0.0 && acc.savings > 0.0
            if acc.loans >= acc.savings
                acc.loans -= acc.savings
                acc.savings = 0.0
            else
                acc.savings -= acc.loans
                acc.loans = 0.0
            end
        end

        # Update wealth (get-shape)
        acc.wealth = acc.savings + acc.wallet
    end
end

# --- Phase 2: bank-balance-sheet ---

function _bres_bank_balance_sheet!(world)
    params = get_resource(world, BRESParams)
    bank = get_resource(world, BRESBank)

    total_savings = 0.0
    total_loans = 0.0
    for (_, _, accounts) in Query(world, (BRESPosition, BRESAccount))
        @inbounds for i in eachindex(accounts)
            total_savings += accounts[i].savings
            total_loans += accounts[i].loans
        end
    end

    bank.bank_deposits = total_savings
    bank.bank_loans = total_loans
    bank.bank_reserves = (params.reserves / 100.0) * total_savings
    bank.bank_to_loan = total_savings - (bank.bank_reserves + total_loans)
end

# --- Stats ---

function _bres_update_stats!(world)
    params = get_resource(world, BRESParams)
    stats = get_resource(world, BRESStats)

    rich = 0; poor = 0; middle = 0
    total_savings = 0.0; total_loans = 0.0; total_wallets = 0.0
    for (_, _, accounts) in Query(world, (BRESPosition, BRESAccount))
        @inbounds for i in eachindex(accounts)
            a = accounts[i]
            total_savings += a.savings
            total_loans += a.loans
            total_wallets += a.wallet
            if a.savings > params.rich_threshold
                rich += 1
            elseif a.loans > 10
                poor += 1
            else
                middle += 1
            end
        end
    end
    stats.rich = rich
    stats.poor = poor
    stats.middle_class = middle
    stats.savings_total = total_savings
    stats.loans_total = total_loans
    stats.wallets_total = total_wallets
    stats.money_total = total_wallets + total_savings
end

# --- Termination ---
struct BRESTerminationSystem <: System end

function update!(::BRESTerminationSystem, world::World)
    params = get_resource(world, BRESParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
