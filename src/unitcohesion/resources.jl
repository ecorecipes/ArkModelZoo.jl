mutable struct UnitCohesionGrid
    width::Int
    height::Int
    age::Matrix{Int}    # -1 = empty, >= 0 = turtle age
    lifespan::Int       # global lifespan (shared by all turtles)
end

function UnitCohesionGrid(w::Int, h::Int, lifespan::Int)
    UnitCohesionGrid(w, h, fill(-1, w, h), lifespan)
end

mutable struct UnitCohesionStats
    n_vacancies::Int
end
UnitCohesionStats() = UnitCohesionStats(0)
