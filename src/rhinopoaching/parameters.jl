Base.@kwdef mutable struct RhinoParams
    width::Int = 101
    height::Int = 101
    num_rhinos::Int = 70
    num_poachers::Int = 4
    num_rangers::Int = 4
    max_roughness::Float64 = 0.6             # fraction of rough terrain
    sprout_delay_time::Int = 500             # ticks before resource sprouts in rough cells
    resource_regrow_rate::Float64 = 0.01     # logistic regrowth rate
    rhino_reproduce_prob::Float64 = 0.01     # per-tick reproduction probability
    poacher_detect_range::Float64 = 5.0      # poacher search radius for rhino signs
    ranger_detect_range::Float64 = 3.0       # ranger detection radius for poachers
    poacher_kill_range::Float64 = 2.0        # poacher kill radius for rhinos
    rhino_forage_radius::Int = 3             # neighbourhood search for foraging
    activity_decay::Float64 = 0.99           # per-tick decay of rhino activity signs
    home_weight::Float64 = 0.3               # weight of home-range fidelity
    resource_weight::Float64 = 0.7           # weight of resource attraction
    max_rhinos::Int = 100                    # pre-allocated capacity
    max_ticks::Int = 200
    seed::Int = 42
end
