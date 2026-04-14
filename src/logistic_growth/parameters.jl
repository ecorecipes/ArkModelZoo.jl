Base.@kwdef mutable struct LGParams
    initial_stock::Float64 = 0.1
    dt::Float64 = 0.01           # System Dynamics Modeler default step
    max_ticks::Int = 1000
    seed::Int = 42
end
