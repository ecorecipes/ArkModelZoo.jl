mutable struct SHSheepPos
    x::Float64
    y::Float64
    heading::Float64
    hidden::Bool
end
SHSheepPos() = SHSheepPos(0.0, 0.0, 0.0, false)

mutable struct SHShepherdState
    x::Float64
    y::Float64
    heading::Float64
    carried_sheep::Entity
    found_herd::Bool
end
SHShepherdState() = SHShepherdState(0.0, 0.0, 0.0, zero_entity, false)
