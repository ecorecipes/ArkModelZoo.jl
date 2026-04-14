# --- Initialization ---

struct InitDecaySystem <: System end

function initialize!(::InitDecaySystem, world::World)
    params = get_resource(world, DecayParams)
    rng = get_resource(world, RNGResource).rng
    stats = get_resource(world, DecayStats)

    w = params.grid_width
    h = params.grid_height
    total_patches = w * h

    # NetLogo: ask n-of number-nuclei patches — picks unique patches
    indices = randperm(rng, total_patches)[1:params.number_nuclei]
    for idx in indices
        x = mod1(idx, w)
        y = div(idx - 1, w) + 1
        new_entity!(world, (NucleusPosition(x, y), ActiveNucleus()))
    end

    stats.total_active = params.number_nuclei
    stats.decays = 0
    return nothing
end

# --- Decay ---

struct DecaySystem <: System
    to_decay::Vector{Entity}
    to_finalize::Vector{Entity}
end
DecaySystem() = DecaySystem(Entity[], Entity[])

function update!(system::DecaySystem, world::World)
    params = get_resource(world, DecayParams)
    rng = get_resource(world, RNGResource).rng
    stats = get_resource(world, DecayStats)

    # Reset decays count for this tick
    stats.decays = 0
    empty!(system.to_decay)
    empty!(system.to_finalize)

    # Phase 1: ask turtles with [color = cyan] — check for decay
    for (eids, _) in Query(world, (NucleusPosition,); with=(ActiveNucleus,))
        @inbounds for i in eachindex(eids)
            if rand(rng) * 100.0 < params.decay_chance
                push!(system.to_decay, eids[i])
            end
        end
    end

    # Apply transitions: ActiveNucleus → JustDecayed
    for e in system.to_decay
        exchange_components!(world, e; add=(JustDecayed(),), remove=(ActiveNucleus,))
        stats.decays += 1
    end

    # Phase 2: ask turtles with [color = yellow] → blue-3
    # Convert all JustDecayed to DecayedNucleus
    for (eids,) in Query(world, (); with=(JustDecayed,))
        @inbounds for i in eachindex(eids)
            push!(system.to_finalize, eids[i])
        end
    end

    for e in system.to_finalize
        exchange_components!(world, e; add=(DecayedNucleus(),), remove=(JustDecayed,))
    end

    return nothing
end

# --- Stats ---

struct DecayStatsSystem <: System end

function update!(::DecayStatsSystem, world::World)
    stats = get_resource(world, DecayStats)

    active_count = 0
    for (eids, _) in Query(world, (NucleusPosition,); with=(ActiveNucleus,))
        active_count += length(eids)
    end
    stats.total_active = active_count

    return nothing
end

# --- Termination ---

struct DecayTerminationSystem <: System end

function update!(::DecayTerminationSystem, world::World)
    params = get_resource(world, DecayParams)
    tick = get_resource(world, Tick)
    stats = get_resource(world, DecayStats)

    if stats.total_active == 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
