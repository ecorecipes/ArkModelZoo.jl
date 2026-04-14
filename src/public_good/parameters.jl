Base.@kwdef mutable struct PGParams
    num_agents::Int = 10
    initial_money::Float64 = 10.0
    multiplier::Float64 = 2.0        # bank is multiplied by this before redistribution
    fraction_put_in::Float64 = 0.5   # fraction of money each agent invests
    punishment_cost::Float64 = 1.0   # cost to punisher and punished
    punish::Bool = false              # whether punishment mechanism is active
    max_ticks::Int = 50
    seed::Int = 42
end
