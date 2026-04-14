mutable struct MDRPosition
    x::Int
    y::Int
end
MDRPosition() = MDRPosition(0, 0)

mutable struct MDRHeading
    heading::Float64
end
MDRHeading() = MDRHeading(0.0)

struct PatientTag end
struct NurseTag end
struct CleanerTag end

mutable struct MDRInfection
    infected::Bool
    energy::Float64
end
MDRInfection() = MDRInfection(false, 2419200.0)
