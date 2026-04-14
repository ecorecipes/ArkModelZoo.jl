mutable struct CivGrid
    RoP::Matrix{Float64}          # productivity per patch
    belongs_to::Matrix{Entity}     # zero_entity = nobody, else civ entity
    conflict_value::Matrix{Int}    # 0 or 1
    width::Int
    height::Int
end

function CivGrid(w::Int, h::Int)
    CivGrid(
        zeros(Float64, w, h),
        fill(zero_entity, w, h),
        zeros(Int, w, h),
        w, h
    )
end

mutable struct CivStats
    n_civs::Int
end
CivStats() = CivStats(0)
