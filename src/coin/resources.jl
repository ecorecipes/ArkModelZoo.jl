# Global COIN state: attendance per day, rewards per day, current global utility
mutable struct CoinState
    attendance::Vector{Int}
    rewards::Vector{Float64}
    current_utility::Float64
end
CoinState() = CoinState(zeros(Int, 7), zeros(Float64, 7), 0.0)
