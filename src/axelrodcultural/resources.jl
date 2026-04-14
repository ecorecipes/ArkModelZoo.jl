mutable struct AxelrodGrid
    width::Int
    height::Int
    traits::Array{Int, 3}  # (F, width, height) — trait values 0..q-1
end

function AxelrodGrid(width::Int, height::Int, F::Int)
    AxelrodGrid(width, height, zeros(Int, F, width, height))
end

mutable struct AxelrodStats
    number_of_cultures::Int
    number_of_active_agents::Int
end
AxelrodStats() = AxelrodStats(0, 0)
