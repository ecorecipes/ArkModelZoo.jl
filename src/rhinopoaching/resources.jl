mutable struct RhinoState
    # Rhinos (pre-allocated to max_rhinos)
    n_rhinos::Int
    rhino_x::Vector{Float64}
    rhino_y::Vector{Float64}
    rhino_heading::Vector{Float64}
    rhino_alive::Vector{Bool}
    rhino_home_x::Vector{Float64}
    rhino_home_y::Vector{Float64}
    rhino_ticks_alive::Vector{Int}
    # Poachers
    n_poachers::Int
    poacher_x::Vector{Float64}
    poacher_y::Vector{Float64}
    poacher_heading::Vector{Float64}
    poacher_alive::Vector{Bool}
    poacher_goal::Vector{Int}   # 0=journey-to, 1=hunting, 2=journey-after
    poacher_caught::Vector{Bool}
    # Rangers
    n_rangers::Int
    ranger_x::Vector{Float64}
    ranger_y::Vector{Float64}
    ranger_heading::Vector{Float64}
    # Grid
    width::Int
    height::Int
    resources::Matrix{Float64}
    max_resources::Matrix{Float64}
    roughness::Matrix{Float64}
    rhino_activity::Matrix{Float64}
    # Stats
    total_killed::Int
end



mutable struct RhinoStats
    n_rhinos::Int
    n_poachers::Int
    total_killed::Int
end
RhinoStats() = RhinoStats(0, 0, 0)
