# Dummy component — World requires at least one registered component type.
# Life is purely patch-based; no ECS entities are used.
mutable struct LFDummy
    _::Int
end
LFDummy() = LFDummy(0)
