# County IDs used in the model
const SLEUTH_COUNTY_IDS = [1, 2, 10, 12, 14, 18, 20, 24, 26, 28, 29, 32, 35, 36, 37, 40, 41, 42, 43, 44, 46, 49, 56]

mutable struct SleuthGrid
    width::Int
    height::Int
    urban::Matrix{Float64}
    county::Matrix{Float64}
    excluded::Matrix{Float64}
    road::Matrix{Float64}
    available::Matrix{Bool}
    capdist::Matrix{Float64}
    county_urban::Dict{Int,Int}     # county_id => urban count
    county_total::Dict{Int,Int}     # county_id => total patch count
end

function SleuthGrid(w::Int, h::Int)
    SleuthGrid(w, h,
        zeros(Float64, w, h),
        zeros(Float64, w, h),
        zeros(Float64, w, h),
        zeros(Float64, w, h),
        falses(w, h),
        zeros(Float64, w, h),
        Dict{Int,Int}(),
        Dict{Int,Int}())
end

mutable struct SleuthStats
    urbantotal::Int
    purbantotal::Float64
    concentration::Float64
end
SleuthStats() = SleuthStats(0, 0.0, 0.0)
