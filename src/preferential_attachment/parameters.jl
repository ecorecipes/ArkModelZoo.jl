Base.@kwdef mutable struct PAParams
    max_nodes::Int = 500       # stop after this many nodes
    max_ticks::Int = 498       # start with 2 nodes, add 1 per tick
    seed::Int = 42
end
