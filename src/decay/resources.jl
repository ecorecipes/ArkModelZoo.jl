mutable struct DecayStats
    decays::Int              # decays this tick
    total_active::Int        # count of active nuclei
end
DecayStats() = DecayStats(0, 0)
