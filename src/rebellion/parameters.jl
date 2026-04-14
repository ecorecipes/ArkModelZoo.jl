Base.@kwdef mutable struct REBParams
    grid_width::Int = 40           # NetLogo: 0-39
    grid_height::Int = 40
    initial_cop_density::Float64 = 4.0    # percent
    initial_agent_density::Float64 = 70.0 # percent
    government_legitimacy::Float64 = 0.82
    max_jail_term::Int = 30
    vision::Float64 = 7.0
    movement::Bool = true
    k::Float64 = 2.3
    threshold::Float64 = 0.1
    max_ticks::Int = 500
    seed::Int = 42
end
