Base.@kwdef mutable struct BullwhipParams
    seed::Int = 47822
    n_customers::Int = 100
    max_purchase::Float64 = 50.0
    n_retailers::Int = 1
    n_wholesalers::Int = 1
    n_distributors::Int = 1
    retailers_increment::Int = 3
    wholesalers_increment::Int = 3
    alien_amount::Int = 400
    return_in_weeks::Int = 10
    num_ticks::Int = 100
end
