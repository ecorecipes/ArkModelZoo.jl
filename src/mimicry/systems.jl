# NetLogo base-colors sublist 1 10 = [15,25,35,45,55,65,75,85,95]
const MIMICRY_MUTATION_COLORS = Float64[15, 25, 35, 45, 55, 65, 75, 85, 95]

# --- Initialization ---

struct InitMimicrySystem <: System end

function initialize!(::InitMimicrySystem, world::World)
    params = get_resource(world, MimicryParams)
    rng = get_resource(world, RNGResource).rng
    stats = get_resource(world, MimicryStats)
    wf = Float64(params.grid_width)
    hf = Float64(params.grid_height)

    # Monarchs (red = 15.0 in NetLogo)
    for _ in 1:params.n_monarchs_init
        x = rand(rng) * wf
        y = rand(rng) * hf
        heading = Float64(rand(rng, 0:359))
        new_entity!(world, (MimicryPosition(x, y), MimicryHeading(heading),
                            MimicryColor(15.0), MonarchTag()))
    end

    # Viceroys (blue = 105.0 in NetLogo)
    for _ in 1:params.n_viceroys_init
        x = rand(rng) * wf
        y = rand(rng) * hf
        heading = Float64(rand(rng, 0:359))
        new_entity!(world, (MimicryPosition(x, y), MimicryHeading(heading),
                            MimicryColor(105.0), ViceroyTag()))
    end

    # Birds (black = 0.0)
    for _ in 1:params.n_birds_init
        x = rand(rng) * wf
        y = rand(rng) * hf
        heading = Float64(rand(rng, 0:359))
        new_entity!(world, (MimicryPosition(x, y), MimicryHeading(heading),
                            MimicryColor(0.0), BirdTag(), BirdMemory()))
    end

    # NetLogo doesn't set n-monarchs/n-viceroys/n-birds in setup;
    # they default to 0 until the first go sets them via count.
    stats.n_monarchs = 0
    stats.n_viceroys = 0
    stats.n_birds = 0
    return nothing
end

# --- Bird movement ---
# NetLogo: set heading 180 + random 180; fd 1

struct MimicryBirdMoveSystem <: System end

function update!(::MimicryBirdMoveSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    params = get_resource(world, MimicryParams)
    wf = Float64(params.grid_width)
    hf = Float64(params.grid_height)

    for (_, positions, headings) in Query(world, (MimicryPosition, MimicryHeading); with=(BirdTag,))
        @inbounds for i in eachindex(positions)
            headings[i].angle = Float64(180 + rand(rng, 0:179))
            θ = deg2rad(headings[i].angle)
            positions[i].x = mod(positions[i].x + sin(θ), wf)
            positions[i].y = mod(positions[i].y + cos(θ), hf)
        end
    end
    return nothing
end

# --- Butterfly movement ---
# NetLogo: rt random 100; lt random 100; fd 1

struct MimicryButterflyMoveSystem <: System end

function update!(::MimicryButterflyMoveSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    params = get_resource(world, MimicryParams)
    wf = Float64(params.grid_width)
    hf = Float64(params.grid_height)

    for (_, positions, headings) in Query(world, (MimicryPosition, MimicryHeading); without=(BirdTag,))
        @inbounds for i in eachindex(positions)
            headings[i].angle += Float64(rand(rng, 0:99) - rand(rng, 0:99))
            θ = deg2rad(headings[i].angle)
            positions[i].x = mod(positions[i].x + sin(θ), wf)
            positions[i].y = mod(positions[i].y + cos(θ), hf)
        end
    end
    return nothing
end

# --- Eating ---
# Butterflies check for bird on same patch. If bird doesn't remember color, butterfly dies.
# If butterfly is monarch, bird learns the color.

mutable struct MimicryEatingSystem <: System
    to_remove::Vector{Entity}
end
MimicryEatingSystem() = MimicryEatingSystem(Entity[])

function _mimicry_color_in_memory(mem::BirdMemory, c::Float64)
    for (mc, _) in mem.memory
        mc == c && return true
    end
    return false
end

function update!(system::MimicryEatingSystem, world::World)
    params = get_resource(world, MimicryParams)
    rng = get_resource(world, RNGResource).rng
    wf = Float64(params.grid_width)
    hf = Float64(params.grid_height)

    empty!(system.to_remove)

    # Build spatial index: patch → list of (bird_eid)
    bird_cells = Dict{Tuple{Int,Int}, Vector{Entity}}()
    for (eids, positions) in Query(world, (MimicryPosition,); with=(BirdTag,))
        @inbounds for i in eachindex(positions)
            px = mod(floor(Int, positions[i].x), params.grid_width) + 1
            py = mod(floor(Int, positions[i].y), params.grid_height) + 1
            key = (px, py)
            if !haskey(bird_cells, key)
                bird_cells[key] = Entity[]
            end
            push!(bird_cells[key], eids[i])
        end
    end

    # Collect all butterflies and shuffle (ask turtles with [breed != birds])
    butterflies = Tuple{Entity, Bool}[]  # (eid, is_monarch)
    for (eids, _) in Query(world, (MimicryPosition,); with=(MonarchTag,))
        @inbounds for i in eachindex(eids)
            push!(butterflies, (eids[i], true))
        end
    end
    for (eids, _) in Query(world, (MimicryPosition,); with=(ViceroyTag,))
        @inbounds for i in eachindex(eids)
            push!(butterflies, (eids[i], false))
        end
    end
    shuffle!(rng, butterflies)

    for (bfly_eid, is_monarch) in butterflies
        is_alive(world, bfly_eid) || continue

        pos = get_components(world, bfly_eid, (MimicryPosition,))[1]
        col = get_components(world, bfly_eid, (MimicryColor,))[1]
        px = mod(floor(Int, pos.x), params.grid_width) + 1
        py = mod(floor(Int, pos.y), params.grid_height) + 1
        key = (px, py)

        birds_here = get(bird_cells, key, nothing)
        birds_here === nothing && continue
        isempty(birds_here) && continue

        # one-of birds-here
        bird_eid = birds_here[rand(rng, 1:length(birds_here))]
        is_alive(world, bird_eid) || continue

        bird_mem = get_components(world, bird_eid, (BirdMemory,))[1]

        if !_mimicry_color_in_memory(bird_mem, col.color)
            # Monarch teaches bird the color
            if is_monarch
                if length(bird_mem.memory) >= params.memory_size
                    popfirst!(bird_mem.memory)
                end
                push!(bird_mem.memory, (col.color, 0))
            end
            # Butterfly dies
            push!(system.to_remove, bfly_eid)
        end
    end

    for e in system.to_remove
        is_alive(world, e) && remove_entity!(world, e)
    end
    return nothing
end

# --- Bird forgetting ---
# Age all memories +1, remove those > memory_duration

struct MimicryForgetSystem <: System end

function update!(::MimicryForgetSystem, world::World)
    params = get_resource(world, MimicryParams)

    for (_, mems) in Query(world, (BirdMemory,))
        @inbounds for i in eachindex(mems)
            mem = mems[i]
            # Age all memories
            for j in eachindex(mem.memory)
                c, a = mem.memory[j]
                mem.memory[j] = (c, a + 1)
            end
            # Remove expired
            filter!(x -> x[2] <= params.memory_duration, mem.memory)
        end
    end
    return nothing
end

# --- Butterfly reproduction ---
# Density-dependent: if random count_breed < cap - count_breed, attempt hatch.
# hatch-butterfly: 4% reproduction chance, 5% mutation.

mutable struct MimicryReproductionSystem <: System
    to_spawn::Vector{Tuple{Float64, Float64, Float64, Float64, Bool}}  # (x, y, heading, color, is_monarch)
end
MimicryReproductionSystem() = MimicryReproductionSystem(Tuple{Float64, Float64, Float64, Float64, Bool}[])

function update!(system::MimicryReproductionSystem, world::World)
    params = get_resource(world, MimicryParams)
    rng = get_resource(world, RNGResource).rng
    wf = Float64(params.grid_width)
    hf = Float64(params.grid_height)

    empty!(system.to_spawn)

    # Count current populations
    n_monarchs = 0
    for (eids, _) in Query(world, (MimicryPosition,); with=(MonarchTag,))
        n_monarchs += length(eids)
    end
    n_viceroys = 0
    for (eids, _) in Query(world, (MimicryPosition,); with=(ViceroyTag,))
        n_viceroys += length(eids)
    end

    # Collect butterflies and shuffle
    butterflies = Tuple{Entity, Bool}[]
    for (eids, _) in Query(world, (MimicryPosition,); with=(MonarchTag,))
        @inbounds for i in eachindex(eids)
            push!(butterflies, (eids[i], true))
        end
    end
    for (eids, _) in Query(world, (MimicryPosition,); with=(ViceroyTag,))
        @inbounds for i in eachindex(eids)
            push!(butterflies, (eids[i], false))
        end
    end
    shuffle!(rng, butterflies)

    for (bfly_eid, is_monarch) in butterflies
        is_alive(world, bfly_eid) || continue

        if is_monarch
            count_breed = n_monarchs
            cap = params.carrying_capacity_monarchs
        else
            count_breed = n_viceroys
            cap = params.carrying_capacity_viceroys
        end

        # Density check: random count_breed < cap - count_breed
        count_breed <= 0 && continue
        deficit = cap - count_breed
        deficit <= 0 && continue
        rand(rng, 0:count_breed-1) < deficit || continue

        # Reproduction chance (4%)
        rand(rng) * 100.0 >= params.reproduction_chance && continue

        pos = get_components(world, bfly_eid, (MimicryPosition,))[1]
        hdg = get_components(world, bfly_eid, (MimicryHeading,))[1]
        col = get_components(world, bfly_eid, (MimicryColor,))[1]

        # Hatch: inherit position/heading, fd 1
        θ = deg2rad(hdg.angle)
        nx = mod(pos.x + sin(θ), wf)
        ny = mod(pos.y + cos(θ), hf)

        # Mutation: 5% chance to change color
        new_color = col.color
        if rand(rng) * 100.0 < params.mutation_rate
            new_color = MIMICRY_MUTATION_COLORS[rand(rng, 1:length(MIMICRY_MUTATION_COLORS))]
        end

        push!(system.to_spawn, (nx, ny, hdg.angle, new_color, is_monarch))

        # Update running count for density check
        if is_monarch
            n_monarchs += 1
        else
            n_viceroys += 1
        end
    end

    for (x, y, heading, color, is_monarch) in system.to_spawn
        if is_monarch
            new_entity!(world, (MimicryPosition(x, y), MimicryHeading(heading),
                                MimicryColor(color), MonarchTag()))
        else
            new_entity!(world, (MimicryPosition(x, y), MimicryHeading(heading),
                                MimicryColor(color), ViceroyTag()))
        end
    end
    return nothing
end

# --- Stats ---

struct MimicryStatsSystem <: System end

function update!(::MimicryStatsSystem, world::World)
    stats = get_resource(world, MimicryStats)
    nm = 0
    for (eids, _) in Query(world, (MimicryPosition,); with=(MonarchTag,))
        nm += length(eids)
    end
    nv = 0
    for (eids, _) in Query(world, (MimicryPosition,); with=(ViceroyTag,))
        nv += length(eids)
    end
    nb = 0
    for (eids, _) in Query(world, (MimicryPosition,); with=(BirdTag,))
        nb += length(eids)
    end
    stats.n_monarchs = nm
    stats.n_viceroys = nv
    stats.n_birds = nb
    return nothing
end

# --- Termination ---

struct MimicryTerminationSystem <: System end

function update!(::MimicryTerminationSystem, world::World)
    params = get_resource(world, MimicryParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
