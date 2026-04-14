Base.@kwdef mutable struct MisSBFCParams
    number_of_agents::Int = 100
    pForget::Float64 = 0.2
    pVerify::Float64 = 0.4
    beta_spreading_rate::Float64 = 0.45
    alpha_hoax_credibility::Float64 = 0.25
    beta_fc_spread::Float64 = 0.55
    pForget_FC::Float64 = 0.05
    max_ticks::Int = 300
    seed::Int = 42
end
