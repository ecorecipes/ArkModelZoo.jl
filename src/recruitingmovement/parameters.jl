Base.@kwdef mutable struct RecMovParams
    n_of_people::Int = 50
    average_people_degree::Int = 6
    n_initiators::Int = 2
    resistance_threshold::Int = 10
    max_ticks::Int = 100
    seed::Int = 42
end
