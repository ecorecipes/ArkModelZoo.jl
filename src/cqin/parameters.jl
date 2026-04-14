Base.@kwdef mutable struct CQINParams
    number_of_nodes::Int = 94
    node_degree::Int = 3
    schema_share_effectiveness::Float64 = 85.0
    schema_check_frequency::Int = 1
    rejection_chance::Float64 = 10.0
    rejection_threshold::Float64 = 25.0
    problem_space_complexity::Float64 = 90.0
    problem_solving_effectiveness::Float64 = 60.0
    coevolution_constraints::Float64 = 50.0
    initial_detection_size::Int = 14
    learning_gain::Float64 = 1.1
    planned_iterations::Int = 20
    signal_base::Float64 = 0.0
    signal_increment::Float64 = 10.0
    signal_target::Float64 = 100.0
    max_non_cooperating::Float64 = 0.5
    max_ticks::Int = 100
    seed::Int = 42
end
