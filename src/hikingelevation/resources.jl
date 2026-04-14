# Grid: 262×184 non-wrapping (NL 0..261 × 0..183)
mutable struct HikeGrid
    width::Int
    height::Int
    elevation::Matrix{Float64}
    tread_count::Matrix{Float64}
    min_elev::Float64
    max_elev::Float64
    goal_x::Int       # 1-indexed grid coords
    goal_y::Int
    entrance_x::Int
    entrance_y::Int
    turtle_count::Int  # total hikers created
end

function HikeGrid(w::Int, h::Int)
    HikeGrid(w, h, zeros(w, h), fill(160.0, w, h),
             0.0, 0.0, 131, 91, 260, 51, 0)
end

mutable struct HikeStats
    track_elevation::Float64
end
HikeStats() = HikeStats(0.0)
