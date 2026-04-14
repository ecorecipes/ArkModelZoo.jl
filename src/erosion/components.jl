# Erosion is a patch-only model — no turtle components needed.
# We use a dummy component so the World has at least one component type.
mutable struct ERDummy
    val::Int
end
ERDummy() = ERDummy(0)
