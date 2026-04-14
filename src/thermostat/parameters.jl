Base.@kwdef mutable struct ThermostatParams
    initial_temp::Int = 53
    goal_temp::Int = 67
    heater_strength::Int = 4
    insulation::Int = 50
    grid_width::Int = 71
    grid_height::Int = 71
    min_cor::Int = -35      # min-pxcor = min-pycor
    max_cor::Int = 35       # max-pxcor = max-pycor
    max_ticks::Int = 1000
    seed::Int = 42
end
