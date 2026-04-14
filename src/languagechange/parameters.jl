Base.@kwdef mutable struct LCParams
    num_nodes::Int = 100
    percent_grammar_1::Float64 = 60.0    # percent starting with grammar 1
    update_algorithm::Symbol = :reward   # :threshold, :individual, or :reward
    threshold_val::Float64 = 0.3
    alpha::Float64 = 0.025
    logistic::Bool = true
    sink_state_1::Bool = false
    max_ticks::Int = 500
    seed::Int = 42
end
