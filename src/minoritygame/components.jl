mutable struct MGAgent
    score::Int
    choice::Int                        # 0 or 1
    strategies::Vector{Vector{Int}}    # list of strategies (each is 2^memory long)
    current_strategy::Int              # index into strategies
    strategies_scores::Vector{Int}     # virtual scores per strategy
end
MGAgent() = MGAgent(0, 0, Vector{Int}[], 1, Int[])
