# Turtle sex: 0 = pink (female), 1 = blue (male)
mutable struct PartySex
    sex::Int
end
PartySex() = PartySex(0)

mutable struct PartyState
    happy::Bool
    my_group_site::Int  # index into group_sites vector (1-based)
end
PartyState() = PartyState(true, 1)

struct PartyTag end
