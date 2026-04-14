# Mailmen (Letter Delivery) – ECS components

# Mailman entity
mutable struct MailmanPosition
    x::Float64
    y::Float64
end
MailmanPosition() = MailmanPosition(0.0, 0.0)

mutable struct MailmanState
    distance_travelled::Float64
    heading::Float64  # current heading in degrees (NetLogo convention: 0=north)
end
MailmanState() = MailmanState(0.0, 0.0)

# Letter entity
mutable struct LetterPosition
    x::Float64
    y::Float64
end
LetterPosition() = LetterPosition(0.0, 0.0)

mutable struct LetterDest
    destination_x::Int
    destination_y::Int
end
LetterDest() = LetterDest(0, 0)

@enum LetterStatus LUncarried=1 LCarried=2 LDelivered=3

mutable struct LetterState
    status::LetterStatus
    carrier::Int  # mailman index (1-based), 0 = no carrier
end
LetterState() = LetterState(LUncarried, 0)
