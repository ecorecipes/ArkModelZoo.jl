mutable struct BullwhipState
    # Customer arrays
    frequency::Vector{Int}
    order_to_retailer::Vector{Float64}
    lucky_number::Vector{Int}
    n_customers::Int

    # Retailer 1 (continuous growth forecast)
    r1_stock::Float64
    r1_buffer::Float64
    r1_backorder::Float64
    r1_demand_log::Vector{Float64}
    r1_prediction::Float64
    r1_prediction_log::Vector{Float64}
    r1_order_to_wholesaler::Float64

    # Retailer 2 (linear growth forecast)
    r2_stock::Float64
    r2_buffer::Float64
    r2_backorder::Float64
    r2_demand_log::Vector{Float64}
    r2_prediction::Float64
    r2_prediction_log::Vector{Float64}
    r2_order_to_wholesaler::Float64

    # Wholesaler
    w_stock::Float64
    w_buffer::Float64
    w_backorder::Float64
    w_demand_log::Vector{Float64}
    w_prediction::Float64
    w_prediction_log::Vector{Float64}
    w_order_to_distributor::Float64

    # Distributor
    d_demand_log::Vector{Float64}
    d_prediction::Float64
    d_prediction_log::Vector{Float64}

    # Return flag for alien strike recovery
    return_flag::Int
end

function BullwhipState()
    return BullwhipState(
        Int[], Float64[], Int[], 0,
        0.0, 0.0, 0.0, Float64[], 0.0, Float64[], 0.0,
        0.0, 0.0, 0.0, Float64[], 0.0, Float64[], 0.0,
        0.0, 0.0, 0.0, Float64[], 0.0, Float64[], 0.0,
        Float64[], 0.0, Float64[],
        0
    )
end

mutable struct BullwhipStats
    n_customers::Int
    r1_stock::Float64
    r2_stock::Float64
    w_stock::Float64
end

BullwhipStats() = BullwhipStats(0, 0.0, 0.0, 0.0)
