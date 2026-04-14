mutable struct CivAgent
    farm_size::Int
    farm_RoP::Float64
    farm_RoC::Float64
    farm_excess::Float64
    excess_prev_tick::Float64
    SoL::Float64
    SoL_max::Float64
    SoL_min::Float64
    RoExp::Float64
    RoExp_prev_tick::Float64
    fs_prev_tick::Int
    choice::Int
    px::Int  # patch x position (1-indexed)
    py::Int  # patch y position (1-indexed)
end
CivAgent() = CivAgent(1, 0.0, 0.0, 0.0, 0.0, 0.0, 5.0, -5.0, 0.0, 0.0, 0, 0, 1, 1)
