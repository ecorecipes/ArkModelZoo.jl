mutable struct PGStudent
    id::Int
    money::Float64
    investment::Float64
    fraction_put_in::Float64
end
PGStudent() = PGStudent(0, 0.0, 0.0, 0.5)
