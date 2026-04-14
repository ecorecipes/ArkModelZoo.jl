mutable struct DUOGrid
    w::Int
    h::Int
    drug_patch::Vector{Bool}   # red patches = drug availability zones
end
DUOGrid() = DUOGrid(0, 0, Bool[])

mutable struct DUONetwork
    adj::Vector{Set{Int}}  # adjacency for agent social network (by slot index)
end
DUONetwork() = DUONetwork(Set{Int}[])

mutable struct DUOStats
    number_overdoses::Int
    num_drug_users::Int
    num_alive::Int
end
DUOStats() = DUOStats(0, 0, 0)
