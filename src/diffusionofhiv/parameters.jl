Base.@kwdef mutable struct HIVParams
    condom_use::Bool = false
    infection_rate::Float64 = 1.0   # 1.0 = 100%, reduced to 0.2 with condom use
    pop_scale::Int = 100000         # divide population by this for agent count
    grid_width::Int = 401
    grid_height::Int = 401
    max_ticks::Int = 100
    seed::Int = 42
end
