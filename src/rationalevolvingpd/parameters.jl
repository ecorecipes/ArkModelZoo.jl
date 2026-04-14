Base.@kwdef mutable struct REPDParams
    grid_size::Int = 51
    num_initial_people::Int = 2000
    people_birth_energy::Float64 = 12.0
    energy_cost_per_person::Float64 = 0.6
    people_birth_threshold::Float64 = 36.0
    relative_genetic_variation::Float64 = 50.0
    max_brain_size::Int = 4
    resource_competition::Float64 = 0.0
    best_competition::Int = 2
    forgetfulness::Float64 = 0.25
    energy_cost_per_neuron::Float64 = 0.0
    # Payoff matrix: [C vs C, C vs D; D vs C, D vs D] = [3, 0; 5, 1]
    payoff_CC::Float64 = 3.0
    payoff_CD::Float64 = 0.0
    payoff_DC::Float64 = 5.0
    payoff_DD::Float64 = 1.0
    # Emotion matrix defaults (same as energy matrix initially)
    emo_CC::Float64 = 3.0
    emo_CD::Float64 = 0.0
    emo_DC::Float64 = 5.0
    emo_DD::Float64 = 1.0
    max_ticks::Int = 100
    seed::Int = 42
end
