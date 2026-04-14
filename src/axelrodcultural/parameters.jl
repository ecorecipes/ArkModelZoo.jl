Base.@kwdef mutable struct AxelrodParams
    F::Int = 3                  # number of cultural features (traits)
    q::Int = 5                  # number of values per trait
    world_size::Int = 10        # 10x10 grid
    max_ticks::Int = 10000
    seed::Int = 42
end
