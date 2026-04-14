Base.@kwdef mutable struct PrvParams
    rows::Int = 5
    cols::Int = 10
    rewire_prob::Float64 = 1.0
    k_neighbors::Int = 2
    adoption_threshold::Float64 = 0.75
    bounded_confidence_threshold::Float64 = 0.35
    hr_minimum_tick_interval::Int = 20
    hr_bounded_confidence_threshold::Float64 = 0.5
    privacy_minimum_tick_interval::Int = 5
    pv_bounded_confidence_threshold::Float64 = 1.0
    enable_hr::Bool = true
    enable_pv::Bool = true
    max_ticks::Int = 200
    seed::Int = 42
end
