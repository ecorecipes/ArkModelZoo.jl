Base.@kwdef mutable struct SWParams
    num_nodes::Int = 40
    rewiring_probability::Float64 = 0.3
    max_ticks::Int = 1          # rewire-all is a single operation
    seed::Int = 42
end
