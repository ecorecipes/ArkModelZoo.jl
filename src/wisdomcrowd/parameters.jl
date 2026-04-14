Base.@kwdef mutable struct WCParams
    population::Int = 50
    tb_perc::Int = 15
    K::Float64 = 0.5
    threshold::Float64 = 0.5
    radius::Float64 = 2.0
    crime_intensity::Int = 3
    alpha::Float64 = 0.5
    norm::Float64 = 0.5
    mobility::Bool = true
    incorporate_guilt::Bool = false
    max_ticks::Int = 200
    seed::Int = 42
end
