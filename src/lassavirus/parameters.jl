# Lassa Virus – parameters with defaults matching NetLogo reference

Base.@kwdef mutable struct LassaParams
    Human_Population::Int = 500
    Multimammate_Rat_Population::Int = 25
    Initial_Number_Of_Cases::Int = 5
    pct_Severe_Cases::Int = 20
    pct_Infectiousness_H2H::Int = 20
    pct_Infectiousness_R2H::Int = 40
    Incubation_Period::Int = 10
    Sick_Days::Int = 15
    CFR_Mild_Case::Int = 1
    CFR_Severe_Case::Int = 15
    Human_Behaviour_Factor::Float64 = 0.8
    Infectious_Days_After_Recovery::Int = 90
    world_min::Int = -16
    world_max::Int = 16
    max_ticks::Int = 500
    seed::Int = 42
end
