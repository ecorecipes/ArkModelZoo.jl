# Species-specific parameters for fungi
struct FBRFungiSpecies
    growth_temp::Float64
    growth_pH::Float64
    enzyme_production_cost::Float64
    enzyme_production_pH::Float64
end

const FBR_SPECIES = Dict(
    "Pleurotus Ostreatus" => FBRFungiSpecies(33.5, 4.0, 2.5, 5.0),
    "Trametes Versicolor" => FBRFungiSpecies(24.0, 1.0, 1.0, 3.75),
    "Phanerodontia Chrysosporium" => FBRFungiSpecies(30.0, 2.0, 1.0, 4.0),
)

mutable struct FBRFungus
    x::Float64
    y::Float64
    age::Float64
    energy::Float64
    NH4::Float64
    partner::Int      # 0 = no partner, else index into ecs vector
    alive::Bool
end

mutable struct FBREnzyme
    x::Float64
    y::Float64
    age::Float64
    heading::Float64
    partner::Int      # 0 = no partner, else index into ecs vector
    turn::Float64
    pause_time::Float64
    alive::Bool
end

mutable struct FBREC
    x::Float64
    y::Float64
    heading::Float64
    partner::Int      # 0 = no partner
    locked_time::Int
    taken::Bool       # absorbed by a fungus intracellularly
    alive::Bool
end

mutable struct FBRPatchGrid
    width::Int
    height::Int
    glucose::Matrix{Float64}
    O2::Matrix{Float64}
    lignin::Matrix{Float64}
end

function FBRPatchGrid(w::Int, h::Int)
    FBRPatchGrid(w, h, fill(4.0, w, h), fill(25.0, w, h), fill(100.0, w, h))
end

mutable struct FBRWorld
    fungi::Vector{FBRFungus}
    enzymes::Vector{FBREnzyme}
    ecs::Vector{FBREC}
    species_params::FBRFungiSpecies
    ec_added::Int
    intracellularly::Int
    Kc::Int
    Kr::Int
    Kd::Int
    complexes_formed::Int
    dissociated::Int
    adjuster_enzymes::Int
    adjuster_fungi::Int
end

function FBRWorld(sp::FBRFungiSpecies)
    FBRWorld(FBRFungus[], FBREnzyme[], FBREC[], sp,
             0, 0, 0, 0, 0, 0, 0, 1, 1)
end

mutable struct FBRStats
    num_fungi::Int
    num_enzymes::Int
    num_ecs::Int
end
FBRStats() = FBRStats(0, 0, 0)
