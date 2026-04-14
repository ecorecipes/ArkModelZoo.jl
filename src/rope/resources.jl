mutable struct RopeState
    n::Int              # number of points (world_width = 161)
    ypos::Vector{Float64}
    yvel::Vector{Float64}
    visible::Vector{Bool}
end
RopeState(n::Int) = RopeState(n, zeros(Float64, n), zeros(Float64, n), trues(n))

mutable struct RopeStats
    n_visible::Int
end
RopeStats() = RopeStats(0)
