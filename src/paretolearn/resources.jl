mutable struct ParetoLearnerState
    n::Vector{Matrix{Int}}   # n[learner][my_action, his_action], 1-indexed actions
    actions::Vector{Int}     # current action per learner (1=cooperate, 2=defect)
    epsilon::Float64         # exploration rate
end

function ParetoLearnerState(epsilon::Float64)
    ParetoLearnerState(
        [ones(Int, 2, 2), ones(Int, 2, 2)],
        [0, 0],
        epsilon,
    )
end

mutable struct ParetoStats
    eu_cooperate::Float64
    eu_defect::Float64
end
ParetoStats() = ParetoStats(0.0, 0.0)
