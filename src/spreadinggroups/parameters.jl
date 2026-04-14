Base.@kwdef mutable struct SGroupParams
    num_nodes::Int = 100
    m::Int = 2
    p::Float64 = 0.11
    gamma::Float64 = 0.5
    num_infected_init::Int = 5
    spreading_group_percent::Float64 = 5.0
    spreading_group_repet::Int = 2
    retention_loss::Bool = true
    size_reduction::Float64 = 1.5
    max_ticks::Int = 100
    seed::Int = 42
end
