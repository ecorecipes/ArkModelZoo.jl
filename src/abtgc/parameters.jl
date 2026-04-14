Base.@kwdef mutable struct ABTParams
    node_count::Int = 14
    edges_to_nodes::Float64 = 3.19
    possible_colors::Int = 6
    grid_size::Int = 33
    max_ticks::Int = 100
    seed::Int = 42
end
