mutable struct LCNode
    state::Float64          # 0.0 to 1.0, grammar state
    spoken_state::Float64   # 0 or 1 after speaking
    node_idx::Int           # index in network
end
LCNode() = LCNode(0.0, 0.0, 0)
