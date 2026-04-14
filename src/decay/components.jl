mutable struct NucleusPosition
    x::Int
    y::Int
end

struct ActiveNucleus end      # cyan — can decay
struct JustDecayed end        # yellow — will become fully decayed next tick
struct DecayedNucleus end     # blue-3 — final state
