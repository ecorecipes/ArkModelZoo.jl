mutable struct GreenPosition
    x::Float64
    y::Float64
end
GreenPosition() = GreenPosition(0.0, 0.0)

mutable struct GreenHeading
    heading::Float64
end
GreenHeading() = GreenHeading(0.0)

mutable struct ActionTaker
    is_action_taker::Bool
end
ActionTaker() = ActionTaker(false)

mutable struct GreenProperties
    locus_of_control::Float64
    sense_of_responsibility::Float64
    pbc::Float64
    social_pressure::Float64
end
GreenProperties() = GreenProperties(0.0, 0.0, 0.0, 0.0)
