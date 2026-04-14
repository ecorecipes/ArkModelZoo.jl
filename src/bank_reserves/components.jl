mutable struct BRESPosition
    x::Int
    y::Int
end
BRESPosition() = BRESPosition(0, 0)

mutable struct BRESAccount
    savings::Float64
    loans::Float64
    wallet::Float64
    wealth::Float64
end
BRESAccount() = BRESAccount(0.0, 0.0, 0.0, 0.0)
