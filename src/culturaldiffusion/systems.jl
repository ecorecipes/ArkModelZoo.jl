# Cultural Diffusion of Programming Languages
# Patches innovate, adopt from neighbors, or forget languages

struct InitCDSystem <: System end

function initialize!(::InitCDSystem, world::World)
    params = get_resource(world, CulturalDiffusionParams)
    st = get_resource(world, CDState)
    stats = get_resource(world, CDStats)

    w = params.grid_width
    h = params.grid_height
    st.w = w
    st.h = h
    n_patches = w * h
    st.langj = [Int[] for _ in 1:n_patches]
    # Census: index 1..MaxLang+1 (language ids 0..MaxLang mapped to 1..MaxLang+1)
    # NetLogo: array:from-list n-values (1 + MaxLang) [5]
    st.census = fill(5, params.max_lang + 1)

    stats.num_iter = 0
    stats.total_langs = sum(st.census)
    return nothing
end

# Helpers for 2D grid indexing (1-based)
_cd_idx(x::Int, y::Int, w::Int) = (y - 1) * w + x

function _cd_weighted_rand_index(rng, probs::Vector{Float64})
    nc = length(probs)
    nc == 0 && return -1
    while true
        i = rand(rng, 1:nc)
        p = probs[i]
        if rand(rng) < p || p >= 0.9999999999
            return i
        end
    end
end

struct CDGoSystem <: System end

function update!(::CDGoSystem, world::World)
    params = get_resource(world, CulturalDiffusionParams)
    rng = get_resource(world, RNGResource).rng
    st = get_resource(world, CDState)
    stats = get_resource(world, CDStats)

    w = st.w
    h = st.h
    n_patches = w * h

    # NetLogo: ask patches [adoption] — shuffled order
    order = collect(1:n_patches)
    Random.shuffle!(rng, order)

    for pidx in order
        py = div(pidx - 1, w) + 1
        px = mod(pidx - 1, w) + 1
        langj = st.langj[pidx]
        check = true

        # Innovation
        if rand(rng) < params.prob_innov
            if length(langj) < params.max_capacity
                l = rand(rng, 1:params.max_lang)
                if !(l in langj)
                    push!(langj, l)
                    st.census[l + 1] += 1  # +1 for 1-based census
                end
            end
            check = false
        end

        # Adoption
        if rand(rng) < params.prob_adoption && check
            nbrs = moore_neighbors_wrap(px, py, w, h)
            # one-of neighbors
            nx, ny = nbrs[rand(rng, 1:length(nbrs))]
            nidx = _cd_idx(nx, ny, w)
            langv = st.langj[nidx]
            if !isempty(langv)
                c_total = sum(st.census)
                # most-frequent-known: weighted by frequency
                if c_total > 0 && length(langv) > 0
                    probs = Float64[st.census[lv + 1] / max(c_total, 1) for lv in langv]
                    sel_idx = length(langv) == 1 ? 1 : _cd_weighted_rand_index(rng, probs)
                    if sel_idx >= 1
                        lv = langv[sel_idx]
                        if !(lv in langj)
                            lenj = length(langj)
                            if lenj >= params.max_capacity
                                # Remove random language
                                ri = rand(rng, 1:lenj)
                                f = langj[ri]
                                deleteat!(langj, ri)
                                st.census[f + 1] -= 1
                            end
                            push!(langj, lv)
                            st.census[lv + 1] += 1
                        end
                    end
                end
            end
            check = false
        end

        # Forget
        if rand(rng) < params.prob_forget && check
            if length(langj) > 1
                c_total = sum(st.census)
                if c_total > 0
                    # least-frequent-known: weighted by 1 - freq
                    probs = Float64[1.0 - st.census[lv + 1] / max(c_total, 1) for lv in langj]
                    sel_idx = length(langj) == 1 ? 1 : _cd_weighted_rand_index(rng, probs)
                    if sel_idx >= 1
                        f = langj[sel_idx]
                        st.census[f + 1] -= 1
                        deleteat!(langj, sel_idx)
                    end
                end
            end
        end
    end

    stats.num_iter += 1
    stats.total_langs = sum(st.census)
    return nothing
end

struct CDTerminationSystem <: System end

function update!(::CDTerminationSystem, world::World)
    params = get_resource(world, CulturalDiffusionParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
