mutable struct CyberGrid
    width::Int
    height::Int
    sentiment::Matrix{Float64}
    extremist::Matrix{Bool}
    vaccinated::Matrix{Bool}
    susceptible::Matrix{Bool}
    infected::Matrix{Bool}
    recovered::Matrix{Bool}
end

function CyberGrid(w::Int, h::Int)
    return CyberGrid(
        w, h,
        zeros(Float64, w, h),
        falses(w, h),
        falses(w, h),
        falses(w, h),
        falses(w, h),
        falses(w, h),
    )
end

mutable struct CyberNetwork
    adj::Vector{Set{Int}}
end

CyberNetwork(n::Int) = CyberNetwork([Set{Int}() for _ in 1:n])

mutable struct CyberStats
    n_infected::Int
    n_recovered::Int
    n_susceptible::Int
end

CyberStats() = CyberStats(0, 0, 0)
