Base.@kwdef mutable struct VoterParams
    grid_width::Int = 50
    grid_height::Int = 50
    max_ticks::Int = 1000
    seed::Int = 42
end
