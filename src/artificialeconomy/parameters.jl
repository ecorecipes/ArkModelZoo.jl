Base.@kwdef mutable struct AEconParams
    width::Int = 40
    height::Int = 40
    population::Int = 60                     # per role (60 farmers + 60 professionals)
    fuel_grow_rate::Float64 = 0.01           # production rate for farmers
    productivity_farmerworld::Float64 = 10.0 # farm production multiplier
    productivity_cityworld::Float64 = 200.0  # widget production multiplier
    depreciation::Float64 = 0.01             # goods decay rate per tick
    produce_supply_level::Float64 = 2000.0   # target produce supply (price formula)
    widget_supply_level::Float64 = 600.0     # target widget supply (price formula)
    markup::Float64 = 10.0                   # price markup percentage
    initial_money::Float64 = 100.0
    interest_rate::Float64 = 0.05            # bank interest rate on loans
    max_debt::Float64 = 500.0                # bankruptcy threshold
    switch_probability::Float64 = 0.05       # prob of considering role switch per tick
    max_ticks::Int = 200
    seed::Int = 42
end
