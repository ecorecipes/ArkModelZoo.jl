mutable struct TGRoad
    width::Int
    height::Int
    is_road::Matrix{Bool}
    is_intersection::Matrix{Bool}
    green_light_up::Matrix{Bool}  # at intersections
    my_phase::Matrix{Int}         # phase for each intersection (-1 = non-intersection)
    signal_color_ns::Matrix{Int}  # 0=red, 1=green, 2=off (north-south signal)
    signal_color_ew::Matrix{Int}  # east-west signal
end

function TGRoad(w::Int, h::Int)
    TGRoad(w, h,
           fill(false, w, h),
           fill(false, w, h),
           fill(true, w, h),
           fill(-1, w, h),
           fill(0, w, h),
           fill(0, w, h))
end

mutable struct TGStats
    num_cars_stopped::Int
    mean_speed::Float64
    mean_wait_time::Float64
end
TGStats() = TGStats(0, 0.0, 0.0)
