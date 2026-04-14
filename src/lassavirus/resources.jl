# Lassa Virus – model-specific resources

mutable struct LassaStats
    infected_not_infectious::Int
    mild_cases_count::Int
    severe_cases_count::Int
    immune_infectious::Int
    immune_not_infectious::Int
    total_immune::Int
    current_cases::Int
    mild_cases::Int        # running total of transitions to mild
    severe_cases::Int      # running total of transitions to severe
    total_mild_cases::Float64
    total_severe_cases::Float64
    total_cases::Float64
    total_infectious::Int
    total_infected::Float64
    total_fatalities::Int
    fatalities::Int        # running total of deaths
    pct_infected::Float64
    pct_uninfected::Float64
    pct_immune::Float64
    average_pct_CFR::Float64
end
LassaStats() = LassaStats(0, 0, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0.0, 0, 0, 0.0, 0.0, 0.0, 0.0)

mutable struct LassaRegistry
    human_entities::Vector{Entity}
    rat_entities::Vector{Entity}
end
LassaRegistry() = LassaRegistry(Entity[], Entity[])
