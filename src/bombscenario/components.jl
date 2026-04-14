mutable struct BombPosition
    x::Int
    y::Int
end
BombPosition() = BombPosition(0, 0)

struct OfficerTag end
struct CitizenTag end
struct BomberTag end

mutable struct BombCitizenState
    going_direction::Int    # 0 or 1
    suspiciousness::Float64
end
BombCitizenState() = BombCitizenState(0, 0.0)
