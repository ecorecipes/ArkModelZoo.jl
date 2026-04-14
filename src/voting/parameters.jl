Base.@kwdef mutable struct VOTParams
    grid_width::Int = 151         # -75..75 = 151 patches
    grid_height::Int = 151
    change_vote_if_tied::Bool = false
    award_close_calls_to_loser::Bool = false
    max_ticks::Int = 200
    seed::Int = 42
end
