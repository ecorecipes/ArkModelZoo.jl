mutable struct VONState
    node_id::Int
    infected::Bool
    resistant::Bool
    virus_check_timer::Int
end
VONState() = VONState(0, false, false, 0)
