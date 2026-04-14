# Patch types
const ALT_HARSH = Int8(0)
const ALT_ALTRUIST = Int8(1)
const ALT_SELFISH = Int8(2)

mutable struct ALTGrid
    width::Int
    height::Int
    ptype::Matrix{Int8}            # 0=harsh, 1=altruist, 2=selfish
    benefit_out::Matrix{Float64}
    altruism_benefit::Matrix{Float64}
    fitness::Matrix{Float64}
    alt_fitness::Matrix{Float64}
    self_fitness::Matrix{Float64}
    harsh_fitness::Matrix{Float64}
end

function ALTGrid(w::Int, h::Int)
    ALTGrid(w, h,
        zeros(Int8, w, h),
        zeros(w, h),
        zeros(w, h),
        zeros(w, h),
        zeros(w, h),
        zeros(w, h),
        zeros(w, h))
end

mutable struct ALTStats
    num_altruists::Int
    num_selfish::Int
    num_harsh::Int
end
ALTStats() = ALTStats(0, 0, 0)
