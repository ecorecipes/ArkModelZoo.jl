mutable struct AIDSPerson
    x::Float64
    y::Float64
    infected::Bool
    known::Bool
    infection_length::Float64
    coupled::Bool
    couple_length::Int
    commitment::Float64
    coupling_tendency::Float64
    condom_use::Float64
    test_frequency::Float64
    is_righty::Bool
    partner_idx::Int      # 0 = no partner (index into person list)
end
AIDSPerson() = AIDSPerson(0.0, 0.0, false, false, 0.0, false, 0, 50.0, 5.0, 0.0, 0.0, true, 0)
