mutable struct TGRoad
    width::Int
    height::Int
    is_road::Matrix{Bool}
    is_intersection::Matrix{Bool}
    green_light_up::Matrix{Bool}  # at intersections
    my_phase::Matrix{Int}         # phase for each intersection (-1 = non-intersection)
    # Patch colors for signal patches: 0=none, 1=red, 2=green, 3=white(road)
    patch_color::Matrix{Int}
    grid_x_inc::Float64
    grid_y_inc::Float64
end

function TGRoad(w::Int, h::Int, gxi::Float64, gyi::Float64)
    TGRoad(w, h,
           fill(false, w, h),
           fill(false, w, h),
           fill(true, w, h),
           fill(-1, w, h),
           fill(0, w, h),
           gxi, gyi)
end

mutable struct TGStats
    num_cars_stopped::Int
    mean_speed::Float64
    mean_wait_time::Float64
end
TGStats() = TGStats(0, 0.0, 0.0)
