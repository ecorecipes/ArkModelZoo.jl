# Cell position (continuous, toroidal wrapping)
mutable struct TumorPosition
    x::Float64
    y::Float64
end

# Persistent heading (degrees, 0=north, clockwise)
mutable struct TumorHeading
    angle::Float64
end

# Cell age (incremented each tick)
mutable struct TumorAge
    age::Int
end

# Tag: stem cell (never dies, always divides)
struct StemCell end

# Tag: metastatic lineage (different death threshold)
struct MetastaticTag end
