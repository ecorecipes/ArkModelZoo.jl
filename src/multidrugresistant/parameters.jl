Base.@kwdef mutable struct MDRParams
    max_ticks::Int = 200
    seed::Int = 42
    data_path::String = ""
    num_patients::Int = 20
    num_nurses::Int = 20
    num_cleaners::Int = 15
end
