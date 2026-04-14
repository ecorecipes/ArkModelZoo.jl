# Mailmen – parameters with defaults matching NetLogo reference

Base.@kwdef mutable struct MailmenParams
    num_mailmen::Int = 5
    num_letters::Int = 30
    min_coord::Int = -10
    max_coord::Int = 10
    max_ticks::Int = 200
    seed::Int = 42
end
