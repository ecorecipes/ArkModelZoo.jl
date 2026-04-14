mutable struct PANode
    node_id::Int
    degree::Int
end
PANode() = PANode(0, 0)
