Base.@kwdef mutable struct PrefAttachHomophilyParams
    number_of_nodes::Int = 80
    number_of_links::Int = 150
    probability_of_homophily::Int = 95
    max_ticks::Int = 150
    seed::Int = 42
end
