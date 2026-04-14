# Grid tracking triggered patches (true = triggered/red)
mutable struct MousetrapGrid
    half_width::Int
    triggered::Matrix{Bool}
end
function MousetrapGrid(half_width::Int)
    dim = 2 * half_width + 1
    return MousetrapGrid(half_width, falses(dim, dim))
end

# Tracked globals: traps-triggered, balls-in-air
mutable struct MousetrapStats
    traps_triggered::Int
    balls_in_air::Int
end
MousetrapStats() = MousetrapStats(0, 0)
