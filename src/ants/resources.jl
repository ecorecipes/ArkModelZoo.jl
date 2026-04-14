# Patch grid holds all per-cell state
mutable struct PatchGrid
    width::Int
    height::Int
    chemical::Matrix{Float64}     # pheromone level
    food::Matrix{Int}             # food amount (0, 1, or 2)
    nest::Matrix{Bool}            # true if nest area
    nest_scent::Matrix{Float64}   # gradient: higher closer to nest
    food_source::Matrix{Int}      # food source identifier (0, 1, 2, or 3)
end

function PatchGrid(width::Int, height::Int)
    PatchGrid(
        width, height,
        zeros(Float64, width, height),
        zeros(Int, width, height),
        falses(width, height),
        zeros(Float64, width, height),
        zeros(Int, width, height),
    )
end

mutable struct AntsStats
    total_food_collected::Int
    total_food_remaining::Int   # sum of food on all patches (NetLogo's "total-food")
    food_source1::Int
    food_source2::Int
    food_source3::Int
end
AntsStats() = AntsStats(0, 0, 0, 0, 0)
