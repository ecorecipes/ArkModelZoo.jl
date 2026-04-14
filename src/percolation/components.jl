# Percolation is a patch-only model; use a dummy component for ECS world
mutable struct PERCDummy
    val::Int
end
PERCDummy() = PERCDummy(0)
