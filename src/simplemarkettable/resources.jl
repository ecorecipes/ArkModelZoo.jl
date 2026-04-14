mutable struct SMktTState
    n_traders::Int
    trader_x::Vector{Float64}
    trader_y::Vector{Float64}
    trader_stock::Vector{Dict{Int,Int}}
    trader_empty::Vector{Bool}
    trader_adj::Vector{Vector{Int}}

    n_shoppers::Int
    shopper_x::Vector{Float64}
    shopper_y::Vector{Float64}
    shopper_list::Vector{Dict{Int,Int}}
    shopper_speed::Vector{Float64}
    shopper_paces::Vector{Float64}
    shopper_currstall::Vector{Int}
    shopper_alive::Vector{Bool}
end

function SMktTState()
    SMktTState(
        0, Float64[], Float64[], Dict{Int,Int}[], Bool[], Vector{Int}[],
        0, Float64[], Float64[], Dict{Int,Int}[], Float64[], Float64[], Int[], Bool[]
    )
end

mutable struct SMktTStats
    n_shoppers_alive::Int
    total_paces::Float64
end
SMktTStats() = SMktTStats(0, 0.0)
