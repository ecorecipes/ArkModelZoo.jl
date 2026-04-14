# Grid: 205×129 non-wrapping (NL -102..102 × -64..64)
# Offset: grid_x = nlx + 103, grid_y = nly + 65
mutable struct MDRGrid
    width::Int
    height::Int
    elevation::Matrix{Float64}
    p_infected::Matrix{Bool}    # environmental contamination
end
function MDRGrid(w::Int, h::Int)
    MDRGrid(w, h, zeros(w, h), fill(false, w, h))
end

mutable struct MDRStats
    dead_patients::Int
    recovered_patients::Int
end
MDRStats() = MDRStats(0, 0)
