# --- Initialization ---

struct InitMarriageSystem <: System end

function initialize!(::InitMarriageSystem, world::World)
    params = get_resource(world, MarriageParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, MarriageState)
    stats = get_resource(world, MarriageStats)
    n = params.num_people

    # Each man gets a shuffled preference list of women (1..n)
    for i in 1:n
        state.man_prefs[i] = randperm(rng, n)
    end
    # Each woman gets a shuffled preference list of men (1..n)
    for i in 1:n
        state.woman_prefs[i] = randperm(rng, n)
    end

    # Initial proposals: all men propose to their first choice
    for i in 1:n
        if !isempty(state.man_prefs[i])
            w = state.man_prefs[i][1]
            state.man_proposal[i] = w
        end
    end

    stats.num_bachelors = count(==(0), state.man_proposal)
    return nothing
end

# --- Proposal Phase (even ticks) ---
# Unmatched men propose to top remaining woman

struct MarriageProposeSystem <: System end

function update!(::MarriageProposeSystem, world::World)
    tick = get_resource(world, Tick)
    # Even ticks: men propose
    tick.tick % 2 != 0 && return nothing

    state = get_resource(world, MarriageState)
    n = length(state.man_proposal)

    for i in 1:n
        if state.man_proposal[i] == 0 && !isempty(state.man_prefs[i])
            w = state.man_prefs[i][1]
            state.man_proposal[i] = w
        end
    end
    return nothing
end

# --- Rejection Phase (odd ticks) ---
# Each woman with multiple proposals keeps the best, rejects the rest

struct MarriageRejectSystem <: System end

function update!(::MarriageRejectSystem, world::World)
    tick = get_resource(world, Tick)
    # Odd ticks: women reject
    tick.tick % 2 != 1 && return nothing

    state = get_resource(world, MarriageState)
    n = length(state.woman_accepted)

    for w in 1:n
        # Find all men proposing to this woman
        suitors = Int[]
        for m in 1:n
            if state.man_proposal[m] == w
                push!(suitors, m)
            end
        end

        length(suitors) <= 1 && continue

        # Sort suitors by woman's preference (lower position = more preferred)
        w_prefs = state.woman_prefs[w]
        sort!(suitors, by = m -> findfirst(==(m), w_prefs))

        # Keep the best (first), reject the rest
        for i in 2:length(suitors)
            s = suitors[i]
            state.man_proposal[s] = 0
            # Remove current top from preferences
            if !isempty(state.man_prefs[s])
                popfirst!(state.man_prefs[s])
            end
        end
    end
    return nothing
end

# --- Stats ---

struct MarriageStatsSystem <: System end

function update!(::MarriageStatsSystem, world::World)
    state = get_resource(world, MarriageState)
    stats = get_resource(world, MarriageStats)
    stats.num_bachelors = count(==(0), state.man_proposal)
    return nothing
end

# --- Termination ---

struct MarriageTerminationSystem <: System end

function update!(::MarriageTerminationSystem, world::World)
    params = get_resource(world, MarriageParams)
    state = get_resource(world, MarriageState)
    tick = get_resource(world, Tick)
    n = params.num_people

    # Stop when all women have exactly 1 proposal
    all_matched = true
    for w in 1:n
        proposal_count = count(==(w), state.man_proposal)
        if proposal_count != 1
            all_matched = false
            break
        end
    end

    if all_matched || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
