Base.@kwdef mutable struct UnitCohesionParams
    grid_width::Int = 40
    grid_height::Int = 25
    replacement_team_size::Int = 8
    initial_lifespan::Int = 156
    replacement_lifespan::Int = 162
    replacement_age::Int = 6
    max_ticks::Int = 500
    seed::Int = 42
end
