Base.@kwdef mutable struct SBotParams
    num_nodes::Int = 200
    m::Int = 2
    p::Float64 = 0.11
    gamma::Float64 = 0.5
    num_infected_init::Int = 5
    reinfect_type::String = "eigenval-centrality"
    bot_group_repet::Int = 2
    bot_group_percent::Int = 5
    retention_loss::Bool = true
    size_reduction::Float64 = 1.5
    max_ticks::Int = 100
    seed::Int = 42
end
