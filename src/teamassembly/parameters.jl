Base.@kwdef mutable struct TeamAssemblyParams
    max_downtime::Int = 40
    p::Float64 = 40.0        # % chance of newcomer (vs incumbent)
    q::Float64 = 65.0        # % chance of picking collaborator of team member
    team_size::Int = 4
    max_ticks::Int = 50
    seed::Int = 42
end
