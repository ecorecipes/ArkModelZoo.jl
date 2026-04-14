Base.@kwdef mutable struct Coordination2GroupsParams
    norm1_prosocial_benefit::Float64 = 8.0
    norm1_coord_benefit::Float64 = 1.0
    norm1_rarity_cost::Float64 = 0.5
    init_norm1_groupA::Float64 = 0.8
    init_norm1_groupB::Float64 = 0.22
    prob_outgroup_observation::Float64 = 0.018
    grid_width::Int = 33
    grid_height::Int = 33
    border_x::Int = 25       # 1-based column for pxcor = max_pxcor/2 = 8
    max_ticks::Int = 200
    seed::Int = 42
end
