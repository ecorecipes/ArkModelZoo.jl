mutable struct SHGrid
    width::Int
    height::Int
    sheep_count::Matrix{Int}  # count of visible sheep per cell
end

function SHGrid(w::Int, h::Int)
    SHGrid(w, h, zeros(Int, w, h))
end

mutable struct SHStats
    herding_efficiency::Float64
    num_sheep_visible::Int
end
SHStats() = SHStats(0.0, 0)
