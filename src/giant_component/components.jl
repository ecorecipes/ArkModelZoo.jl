mutable struct GCDummy
    _::Int
end
GCDummy() = GCDummy(0)
