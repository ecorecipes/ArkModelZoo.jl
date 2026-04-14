mutable struct REBAgent
    x::Int
    y::Int
    risk_aversion::Float64
    perceived_hardship::Float64
    active::Bool
    jail_term::Int
end
REBAgent() = REBAgent(0, 0, 0.0, 0.0, false, 0)

mutable struct REBCop
    x::Int
    y::Int
end
REBCop() = REBCop(0, 0)
