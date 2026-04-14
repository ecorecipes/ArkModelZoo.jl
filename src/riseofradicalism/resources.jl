mutable struct RadTerroristCluster
    x::Int
    y::Int
    radicalism::Float64
    alive::Bool
end

mutable struct RadTownship
    x::Int
    y::Int
    overtaken::Bool
end

mutable struct RadGrid
    width::Int
    height::Int
    elevation::Matrix{Float64}
    tslb::Matrix{Float64}
    radical_spread_value::Matrix{Float64}
    wetness::Matrix{Float64}
    slope::Matrix{Float64}
    cell::Matrix{Float64}
    radicalism_spread_area::Matrix{Float64}
    radicalism_spread_area_time::Matrix{Float64}
    spread_ability::Matrix{Float64}
    radicalized::Matrix{Bool}
end

function RadGrid(w::Int, h::Int)
    RadGrid(w, h,
        zeros(Float64, w, h),
        zeros(Float64, w, h),
        zeros(Float64, w, h),
        zeros(Float64, w, h),
        ones(Float64, w, h),
        ones(Float64, w, h),
        fill(100.0, w, h),
        ones(Float64, w, h),
        zeros(Float64, w, h),
        falses(w, h))
end

mutable struct RadState
    terrorist_clusters::Vector{RadTerroristCluster}
    townships::Vector{RadTownship}
    network::NwGraph
end
RadState() = RadState(RadTerroristCluster[], RadTownship[], NwGraph())

mutable struct RadStats
    percent_radicals::Float64
    overtaken_townships::Float64
    total_radicalism::Float64
end
RadStats() = RadStats(0.0, 0.0, 0.0)
