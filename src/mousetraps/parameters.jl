Base.@kwdef mutable struct MousetrapParams
    max_distance::Float64 = 4.5   # random-float max-distance
    half_width::Int = 80          # world from -80 to 80 → 161×161 patches
    max_ticks::Int = 150
    seed::Int = 42
end
