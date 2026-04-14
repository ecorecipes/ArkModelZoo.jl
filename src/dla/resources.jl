# Grid tracking which patches are part of the cluster (green in NetLogo)
mutable struct DLAGrid
    width::Int
    height::Int
    cluster::Matrix{Bool}
end
DLAGrid(w::Int, h::Int) = DLAGrid(w, h, falses(w, h))

# Tracked globals matching NetLogo
mutable struct DLAStats
    n_remaining::Int
end
DLAStats() = DLAStats(0)
