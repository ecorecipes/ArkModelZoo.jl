mutable struct DrugPosition
    x::Float64
    y::Float64
end
DrugPosition() = DrugPosition(0.0, 0.0)

mutable struct DrugHeading
    angle::Float64
end
DrugHeading() = DrugHeading(0.0)

mutable struct DrugState
    drug_user::Bool
    drug_level::Float64
    unemployed::Bool
end
DrugState() = DrugState(false, 0.0, false)
