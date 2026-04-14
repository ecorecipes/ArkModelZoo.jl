mutable struct SGABits
    bits::Vector{Int}
    fitness::Int
end
SGABits() = SGABits(Int[], 0)
