mutable struct OpinionBCPopulation
    opinions::Vector{Float64}
end
OpinionBCPopulation(n::Int) = OpinionBCPopulation(zeros(Float64, n))

mutable struct OpinionBCStats
    mean_opinion::Float64
    sd_opinion::Float64
end
OpinionBCStats() = OpinionBCStats(0.0, 0.0)
