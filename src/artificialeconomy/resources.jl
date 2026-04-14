mutable struct AEconState
    n_agents::Int
    is_farmer::Vector{Bool}
    x::Vector{Int}
    y::Vector{Int}
    money::Vector{Float64}
    produce::Vector{Float64}
    widget::Vector{Float64}
    debt::Vector{Float64}
    alive::Vector{Bool}
    last_income::Vector{Float64}
    # Store state
    store_produce::Float64
    store_widget::Float64
    store_money::Float64
    # Prices
    produce_price::Float64
    widget_price::Float64
    # Bank state
    farmer_bank_capital::Float64
    professional_bank_capital::Float64
    farmer_interest_rate::Float64
    professional_interest_rate::Float64
    # Trade tracking for price setting
    total_produce_traded::Float64
    total_widget_traded::Float64
    # Grid
    width::Int
    height::Int
    farm_yield::Matrix{Float64}
end



mutable struct AEconStats
    n_farmers::Int
    n_professionals::Int
    mean_money::Float64
    produce_price::Float64
    widget_price::Float64
end
AEconStats() = AEconStats(0, 0, 0.0, 0.0, 0.0)
