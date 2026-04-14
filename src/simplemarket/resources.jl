mutable struct SMktState
    n_traders::Int
    trader_x::Vector{Float64}
    trader_y::Vector{Float64}
    trader_stock::Vector{Dict{Int,Int}}
    trader_empty::Vector{Bool}

    n_shoppers::Int
    shopper_x::Vector{Float64}
    shopper_y::Vector{Float64}
    shopper_list::Vector{Dict{Int,Int}}
    shopper_speed::Vector{Float64}
    shopper_paces::Vector{Float64}
    shopper_currstall::Vector{Int}
    shopper_alive::Vector{Bool}
end

function SMktState()
    SMktState(
        0, Float64[], Float64[], Dict{Int,Int}[], Bool[],
        0, Float64[], Float64[], Dict{Int,Int}[], Float64[], Float64[], Int[], Bool[]
    )
end

mutable struct SMktStats
    active_shoppers::Int
    empty_traders::Int
end
SMktStats() = SMktStats(0, 0)
