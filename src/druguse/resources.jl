mutable struct DrugGrid
    width::Int
    height::Int
    drug_sites::Matrix{Bool}  # true = red patch (drug site)
end
function DrugGrid(w::Int, h::Int)
    DrugGrid(w, h, falses(w, h))
end

mutable struct DrugNetwork
    neighbors::Dict{Entity, Vector{Entity}}
end
DrugNetwork() = DrugNetwork(Dict{Entity, Vector{Entity}}())

mutable struct DrugStats
    number_overdoses::Int
    population::Int
end
DrugStats() = DrugStats(0, 0)
