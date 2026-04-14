mutable struct REPDState
    width::Int
    height::Int
    n_patches::Int
    alive::Vector{Bool}
    energy::Vector{Float64}
    # Emotion matrix per patch: 2×2 stored as 4 values [CC, CD, DC, DD]
    emo_matrix::Matrix{Float64}   # n_patches × 4
    # Neurons: imprint utility per event pattern, n_patches × 4
    # Event patterns: [C,C]=1, [C,D]=2, [D,C]=3, [D,D]=4
    neuron_imprint::Matrix{Float64}  # n_patches × 4
    counter::Vector{Int}
    partner::Vector{Int}         # 0 = no partner
    current_event::Vector{Int}   # last event pattern index (1-4), 0=none
    my_move::Vector{Int}         # 0=defect, 1=cooperate
    played::Vector{Bool}
    score::Vector{Float64}
end

function REPDState(w::Int, h::Int)
    n = w * h
    REPDState(
        w, h, n,
        fill(false, n),
        zeros(Float64, n),
        zeros(Float64, n, 4),
        zeros(Float64, n, 4),
        zeros(Int, n),
        zeros(Int, n),
        zeros(Int, n),
        zeros(Int, n),
        fill(false, n),
        zeros(Float64, n),
    )
end

mutable struct REPDStats
    n_alive::Int
    n_neurons::Int
end
REPDStats() = REPDStats(0, 0)
