mutable struct DUOPosition
    x::Float64
    y::Float64
end

mutable struct DUOHeading
    angle::Float64
end

mutable struct DUOAgentState
    drug_user::Bool
    drug_level::Float64
    unemployed::Bool
    alive::Bool
    slot::Int       # index into network adjacency
end

struct DUOTag end
