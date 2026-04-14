Base.@kwdef mutable struct RecSupParams
    n_of_people::Int = 30
    average_people_degree::Int = 4
    n_initiators::Int = 1
    resistance_threshold::Int = 20
    max_ticks::Int = 50
    seed::Int = 42
end
