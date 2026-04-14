mutable struct MSISState
    n::Int
    states::Vector{Int}     # 0=susceptible, 1=infected
    marked::Vector{Bool}
end
MSISState() = MSISState(0, Int[], Bool[])

mutable struct MSISStats
    reproduction_number::Float64
    new_infected::Int
end
MSISStats() = MSISStats(0.0, 0)
