mutable struct CDState
    w::Int
    h::Int
    langj::Vector{Vector{Int}}    # langj[patch_idx] = list of language ids
    census::Vector{Int}           # census[lang_id] = global count
end

function CDState()
    CDState(0, 0, Vector{Int}[], Int[])
end

mutable struct CDStats
    num_iter::Int
    total_langs::Int
end
CDStats() = CDStats(0, 0)
