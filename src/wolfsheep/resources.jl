# Grid of grass state: countdown[x,y] <= 0 means green (alive), > 0 means brown (regrowing)
mutable struct GrassGrid
    width::Int
    height::Int
    countdown::Matrix{Int}
end

function GrassGrid(width::Int, height::Int)
    GrassGrid(width, height, zeros(Int, width, height))
end

mutable struct WSPopulationStats
    sheep_count::Int
    wolf_count::Int
    grass_count::Int
end
WSPopulationStats() = WSPopulationStats(0, 0, 0)
