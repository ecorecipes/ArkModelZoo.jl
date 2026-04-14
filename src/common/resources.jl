mutable struct Tick
    tick::Int
end

mutable struct Terminate
    stop::Bool
end

mutable struct RNGResource
    rng::Xoshiro
end
