mutable struct FFFirefly
    x::Float64
    y::Float64
    clock::Int
    threshold::Int
    reset_level::Int
    window::Int
    flashing::Bool
end
FFFirefly() = FFFirefly(0.0, 0.0, 0, 1, 0, -1, false)
