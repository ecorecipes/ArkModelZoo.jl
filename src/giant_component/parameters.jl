Base.@kwdef mutable struct GCParams
    num_nodes::Int = 80
    max_ticks::Int = 5000  # enough for full connection
    seed::Int = 42
end
