# Utility weights for 7 days, and last chosen action (1-indexed, 0 = not yet acted)
mutable struct CoinAgent
    u::Vector{Float64}
    last_action::Int
end
CoinAgent() = CoinAgent(fill(100.0, 7), 0)
