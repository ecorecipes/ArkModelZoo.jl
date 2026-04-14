# Grid occupancy
mutable struct EthnoGrid
    width::Int
    height::Int
    cells::Matrix{Entity}
end

function EthnoGrid(w::Int, h::Int)
    EthnoGrid(w, h, fill(zero_entity, w, h))
end

# Running statistics
mutable struct EthnoStats
    # Per-tick counts
    meet::Int
    meetown::Int
    meetother::Int
    coopown::Int
    coopother::Int
    defother::Int
    # Strategy percentages (rolling 100-tick window)
    cc_history::Vector{Float64}  # altruist
    cd_history::Vector{Float64}  # ethnocentric
    dc_history::Vector{Float64}  # cosmopolitan
    dd_history::Vector{Float64}  # egoist
    total_population::Int
end

function EthnoStats()
    EthnoStats(0, 0, 0, 0, 0, 0,
               Float64[], Float64[], Float64[], Float64[], 0)
end

function clear_tick_stats!(stats::EthnoStats)
    stats.meet = 0
    stats.meetown = 0
    stats.meetother = 0
    stats.coopown = 0
    stats.coopother = 0
    stats.defother = 0
end
