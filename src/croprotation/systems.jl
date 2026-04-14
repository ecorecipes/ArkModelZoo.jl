# --- Initialization ---

struct InitCRSystem <: System end

function initialize!(::InitCRSystem, world::World)
    params = get_resource(world, CRParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, CRState)
    stats = get_resource(world, CRStats)

    for i in 1:state.n_patches
        state.nitrogen[i] = max(0.0, randn(rng) * params.init_nitrogen_sd + params.init_nitrogen_mean)
        state.current_crop[i] = CR_FALLOW
        state.previous_crop[i] = CR_FALLOW
        state.harvest_week[i] = 0  # will plant at tick 0
        state.last_yield[i] = 1.0
        empty!(state.crop_history[i])
        state.available_crops[i] = Set(1:12)
    end

    stats.n_active_crops = 0
    return nothing
end

# --- Weekly step: check if harvest/plant time ---

struct CRWeeklySystem <: System end

function update!(::CRWeeklySystem, world::World)
    params = get_resource(world, CRParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, CRState)
    tick = get_resource(world, Tick).tick

    for i in 1:state.n_patches
        if tick == state.harvest_week[i]
            if state.current_crop[i] != CR_FALLOW || tick == 0
                if tick > 0
                    _cr_harvest!(state, params, rng, i)
                end
                _cr_plant!(state, params, rng, i, tick)
            end
        end
    end
    return nothing
end

function _cr_harvest!(state::CRState, params::CRParams, rng, idx::Int)
    crop_id = state.current_crop[idx]
    if crop_id == CR_FALLOW
        return
    end

    crop_info = state.crop_table[crop_id + 1]  # +1 for 1-based indexing

    # Weed loss
    weed_loss = tanh(rand(rng) * crop_info.weed_suscept)
    # Disease loss
    disease_loss = tanh(rand(rng) * crop_info.disease_suscept)

    yield_val = (1.0 - weed_loss) * (1.0 - disease_loss)
    state.last_yield[idx] = yield_val

    # Nitrogen depletion from crop
    state.nitrogen[idx] -= crop_info.nitrogen_req * yield_val
    # Nitrogen fixation (legumes, cover crops)
    state.nitrogen[idx] += crop_info.nitrogen_fix
    state.nitrogen[idx] = max(0.0, state.nitrogen[idx])

    # Remove crop from available if heavily damaged by disease or weeds
    if disease_loss > 0.5 || weed_loss > 0.5
        delete!(state.available_crops[idx], crop_id)
    end

    state.previous_crop[idx] = crop_id
    push!(state.crop_history[idx], crop_id)
end

function _cr_plant!(state::CRState, params::CRParams, rng, idx::Int, tick::Int)
    crop_id = _cr_select_crop(state, params, rng, idx)
    state.current_crop[idx] = crop_id

    crop_info = state.crop_table[crop_id + 1]
    state.harvest_week[idx] = tick + crop_info.harvest_weeks
end

function _cr_select_crop(state::CRState, params::CRParams, rng, idx::Int)
    available = state.available_crops[idx]
    prev = state.previous_crop[idx]
    nitrogen = state.nitrogen[idx]
    last_yield = state.last_yield[idx]

    # Rule 2: no possible crops → fallow
    if isempty(available)
        return CR_FALLOW
    end

    # Rule 3: previous yield very low → fallow
    if last_yield < params.low_yield_threshold && prev != CR_FALLOW
        return CR_FALLOW
    end

    # Rule 4: random fallow chance (5%)
    if rand(rng) < params.fallow_chance
        return CR_FALLOW
    end

    # Rule 5a/b: low nitrogen → cover crop or legume
    if nitrogen < 3.0
        if CR_COVER in available
            return CR_COVER
        end
        if 6 in available  # legume
            return 6
        end
        return CR_FALLOW
    end

    # Rule 6: filter by nitrogen requirement
    feasible = Set{Int}()
    for c in available
        if state.crop_table[c + 1].nitrogen_req <= nitrogen
            push!(feasible, c)
        end
    end

    if isempty(feasible)
        return CR_FALLOW
    end

    # Rule 7: remove previous crop (no immediate repeat)
    if prev in feasible && length(feasible) > 1
        delete!(feasible, prev)
    end

    # Rule 8: filter by oversaturation (same family planted recently)
    if length(state.crop_history[idx]) >= 3
        recent = state.crop_history[idx][max(1, end-2):end]
        oversaturated = Set{Int}()
        for c in feasible
            if count(==(c), recent) >= 2
                push!(oversaturated, c)
            end
        end
        if length(feasible) > length(oversaturated)
            setdiff!(feasible, oversaturated)
        end
    end

    if isempty(feasible)
        return CR_FALLOW
    end

    # Rule 9-12: preference for nitrogen fixers when nitrogen is moderate
    if nitrogen < 6.0
        n_fixers = filter(c -> state.crop_table[c + 1].nitrogen_fix > 0.0, collect(feasible))
        if !isempty(n_fixers)
            return n_fixers[rand(rng, 1:length(n_fixers))]
        end
    end

    # Rule 13: random from feasible
    feasible_vec = collect(feasible)
    return feasible_vec[rand(rng, 1:length(feasible_vec))]
end

# --- Stats ---

struct CRStatsSystem <: System end

function update!(::CRStatsSystem, world::World)
    state = get_resource(world, CRState)
    stats = get_resource(world, CRStats)
    n_active = 0
    for i in 1:state.n_patches
        if state.current_crop[i] != CR_FALLOW
            n_active += 1
        end
    end
    stats.n_active_crops = n_active
    return nothing
end

# --- Termination ---

struct CRTerminationSystem <: System end

function update!(::CRTerminationSystem, world::World)
    params = get_resource(world, CRParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
