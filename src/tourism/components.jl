# Tourism Destination model – ECS components

mutable struct TourismVisitor
    revisit_interval::Int
    evaluation::Int
    is_social::Bool
    at_destination::Bool
end
TourismVisitor() = TourismVisitor(1, 0, false, false)
