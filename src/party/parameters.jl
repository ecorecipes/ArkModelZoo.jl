Base.@kwdef mutable struct PartyParams
    num_groups::Int = 10
    number::Int = 70               # number of turtles
    tolerance::Float64 = 25.0      # percent tolerance
    world_width::Int = 82          # -80..1 → 82 patches
    world_height::Int = 111        # -55..55 → 111 patches
    max_ticks::Int = 1000
    seed::Int = 42
end
