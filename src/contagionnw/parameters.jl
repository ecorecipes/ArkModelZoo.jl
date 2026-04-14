Base.@kwdef mutable struct ContagionNWParams
    number_of_links::Int = 100
    probability_linked_affected::Int = 50
    probability_other_affected::Int = 1
    max_ticks::Int = 200
    seed::Int = 42
end
