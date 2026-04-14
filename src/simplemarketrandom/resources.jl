mutable struct SMktRState
    n_traders::Int
    trader_x::Vector{Float64}
    trader_y::Vector{Float64}
    trader_stock::Vector{Dict{Int,Int}}
    trader_empty::Vector{Bool}

    n_shoppers::Int
    shopper_x::Vector{Float64}
    shopper_y::Vector{Float64}
    shopper_list::Vector{Dict{Int,Int}}
    shopper_currstall::Vector{Int}
    shopper_alive::Vector{Bool}
end

function SMktRState()
    SMktRState(
        0, Float64[], Float64[], Dict{Int,Int}[], Bool[],
        0, Float64[], Float64[], Dict{Int,Int}[], Int[], Bool[]
    )
end

mutable struct SMktRStats
    num_shoppers_left::Int
    num_traders_with_stock::Int
end
SMktRStats() = SMktRStats(0, 0)
