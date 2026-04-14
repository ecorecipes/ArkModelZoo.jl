# Dummy component — World requires at least one registered component type.
# Altruism is purely patch-based; no ECS entities are used.
mutable struct ALTDummy
    _::Int
end
ALTDummy() = ALTDummy(0)
