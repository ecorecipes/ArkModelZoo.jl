Base.@kwdef mutable struct LTechParams
    number_expecting_a::Int = 1
    number_expecting_b::Int = 55
    number_expecting_both::Int = 0
    number_no_expectations::Int = 44
    technology_affordances::Vector{String} = ["a"]
    limited_persistence::Bool = true
    tech_transparency::Float64 = 0.1
    can_learn_unexpectedly::Bool = true
    use_can_fail::Bool = true
    proportion_material_influence::Float64 = 0.05
    max_ticks::Int = 200
    seed::Int = 42
end

function _ltech_total_num(params::LTechParams)
    return params.number_expecting_a + params.number_expecting_b +
           params.number_expecting_both + params.number_no_expectations
end
