Base.@kwdef mutable struct CA1DParams
    grid_width::Int = 101      # number of cells in 1D row
    grid_height::Int = 100     # number of time steps (rows)
    rule::Int = 30             # Wolfram rule number (0-255)
    density::Float64 = 50.0    # percent on for random init
    random_init::Bool = false  # false = single center cell
    max_ticks::Int = 99        # grid_height - 1 time steps
    seed::Int = 42
end
