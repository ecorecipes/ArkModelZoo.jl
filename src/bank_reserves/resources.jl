mutable struct BRESBank
    bank_loans::Float64
    bank_reserves::Float64
    bank_deposits::Float64
    bank_to_loan::Float64
end
BRESBank() = BRESBank(0.0, 0.0, 0.0, 0.0)

mutable struct BRESStats
    rich::Int
    poor::Int
    middle_class::Int
    money_total::Float64
    savings_total::Float64
    loans_total::Float64
    wallets_total::Float64
end
BRESStats() = BRESStats(0, 0, 0, 0.0, 0.0, 0.0, 0.0)
