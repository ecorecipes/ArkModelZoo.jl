mutable struct PrvNetwork
    n::Int
    adjacency::Vector{Set{Int}}
    attitudes::Vector{Float64}
    updated_attitudes::Vector{Float64}
    willingness::Vector{Float64}
    adopted::Vector{Bool}
end

function PrvNetwork(n::Int)
    PrvNetwork(
        n,
        [Set{Int}() for _ in 1:n],
        zeros(Float64, n),
        zeros(Float64, n),
        zeros(Float64, n),
        fill(false, n),
    )
end

mutable struct PrvCounters
    hr_tick_counter::Int
    hr_tick_interval::Int
    pv_tick_counter::Int
    pv_tick_interval::Int
end
PrvCounters(hr_int::Int, pv_int::Int) = PrvCounters(0, hr_int, 0, pv_int)

mutable struct PrvStats
    adopters_total::Int
    adopter_percent::Float64
end
PrvStats() = PrvStats(0, 0.0)
