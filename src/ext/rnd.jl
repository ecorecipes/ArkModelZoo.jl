# Weighted random sampling (NetLogo rnd extension equivalent)

"""
    weighted_one_of(rng, items, weights) -> item

Select one item with probability proportional to its weight.
Equivalent to NetLogo `rnd:weighted-one-of`.
"""
function weighted_one_of(rng::AbstractRNG, items, weights)
    @assert length(items) == length(weights)
    total = sum(weights)
    total <= 0.0 && return items[rand(rng, 1:length(items))]
    r = rand(rng) * total
    cumul = 0.0
    for (item, w) in zip(items, weights)
        cumul += w
        if cumul >= r
            return item
        end
    end
    return items[end]
end

"""
    weighted_one_of(rng, items, weight_fn) -> item

Select one item with probability proportional to `weight_fn(item)`.
"""
function weighted_one_of(rng::AbstractRNG, items, weight_fn::Function)
    weights = [weight_fn(x) for x in items]
    return weighted_one_of(rng, items, weights)
end

"""
    weighted_n_of(rng, n, items, weights) -> Vector

Select n items without replacement, with probability proportional to weights.
Equivalent to NetLogo `rnd:weighted-n-of`.
"""
function weighted_n_of(rng::AbstractRNG, n::Int, items, weights)
    @assert length(items) == length(weights)
    n = min(n, length(items))
    result = similar(items, 0)
    ws = collect(Float64, weights)
    idxs = collect(1:length(items))
    for _ in 1:n
        total = sum(ws)
        if total <= 0.0
            # pick uniformly from remaining
            j = rand(rng, 1:length(idxs))
        else
            r = rand(rng) * total
            cumul = 0.0
            j = length(idxs)
            for k in 1:length(idxs)
                cumul += ws[k]
                if cumul >= r
                    j = k
                    break
                end
            end
        end
        push!(result, items[idxs[j]])
        deleteat!(idxs, j)
        deleteat!(ws, j)
    end
    return result
end

"""
    weighted_n_of_with_repeats(rng, n, items, weights) -> Vector

Select n items with replacement, with probability proportional to weights.
Equivalent to NetLogo `rnd:weighted-n-of-with-repeats`.
"""
function weighted_n_of_with_repeats(rng::AbstractRNG, n::Int, items, weights)
    result = similar(items, 0)
    for _ in 1:n
        push!(result, weighted_one_of(rng, items, weights))
    end
    return result
end
