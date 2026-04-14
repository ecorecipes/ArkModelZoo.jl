Base.@kwdef mutable struct BSitParams
    co_op_size::Int = 100
    initial_scrip::Float64 = 25.0
    mean_hours_out::Int = 4
    want_to_go_out_probability::Float64 = 0.5
    want_to_sit_probability::Float64 = 0.5
    monthly_dues::Float64 = 0.6
    desired_times_out_reserve::Float64 = 0.0
    willing_to_sit_prob::Float64 = 0.0
    years::Int = 10
    cycle_amplitude::Float64 = 0.0
    multiple_sitees::Bool = true
    clear_sitter_market::Bool = false
    auto_adjust::Bool = false
    hours_out_distribution::String = "uniform"
    max_ticks::Int = 3650   # 365 * years
    seed::Int = 42
end
