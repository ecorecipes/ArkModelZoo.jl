Base.@kwdef mutable struct VirusParams
    number_people::Int = 150
    initial_infected::Int = 3
    virus_spread_chance::Float64 = 0.10
    virus_check_freq::Int = 10
    recovery_chance::Float64 = 0.25
    lose_immunity_chance::Float64 = 0.01
    link_radius::Float64 = 3.0
    world_width::Int = 33          # NetLogo default: -16 to 16
    world_height::Int = 33
    max_ticks::Int = 150
    seed::Int = 42
end

mutable struct VirusStats
    num_susceptible::Int
    num_infected::Int
    num_resistant::Int
end
VirusStats() = VirusStats(0, 0, 0)

# Static contact network built at initialization
mutable struct VirusNetwork
    neighbors::Dict{Entity, Vector{Entity}}
end
VirusNetwork() = VirusNetwork(Dict{Entity, Vector{Entity}}())
