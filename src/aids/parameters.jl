Base.@kwdef mutable struct AIDSParams
    initial_people::Int = 300
    average_commitment::Float64 = 50.0
    average_coupling_tendency::Float64 = 5.0
    average_condom_use::Float64 = 0.0
    average_test_frequency::Float64 = 0.0
    infection_chance::Float64 = 50.0     # percent per coupling week
    symptoms_show::Float64 = 200.0       # weeks until symptoms
    grid_width::Int = 25
    grid_height::Int = 25
    max_ticks::Int = 500
    seed::Int = 42
end
