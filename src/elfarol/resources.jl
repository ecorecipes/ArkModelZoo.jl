# Global attendance history (most recent first)
mutable struct ElFarolHistory
    history::Vector{Int}
end
ElFarolHistory(n::Int) = ElFarolHistory(zeros(Int, n))

mutable struct ElFarolStats
    attendance::Int
end
ElFarolStats() = ElFarolStats(0)
