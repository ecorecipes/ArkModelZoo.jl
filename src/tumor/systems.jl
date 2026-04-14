# --- Initialization ---
# NetLogo: create 2 stem cells at (min-pxcor/2, 0) = (-25.5, 0).
# Turtle 0: non-metastatic stem, default heading (0).
# Turtle 1: metastatic stem, heading 90.

struct InitTumorSystem <: System end

function initialize!(::InitTumorSystem, world::World)
    params = get_resource(world, TumorParams)
    stats = get_resource(world, TumorStats)
    wf = Float64(params.grid_width)

    # Non-metastatic stem (turtle 0): position (min-pxcor/2, 0) in NetLogo coords.
    # In our [0, 103) space: x = (-51/2 + 51.5) = 26.0, y = 51.5
    # Actually min-pxcor = -51, min-pxcor/2 = -25.5.
    # Mapped to [0,103): x = -25.5 + 51.5 = 26.0, y = 0 + 51.5 = 51.5
    stem0_x = 26.0
    stem0_y = 51.5
    new_entity!(world, (
        TumorPosition(stem0_x, stem0_y),
        TumorHeading(0.0),
        TumorAge(0),
        StemCell(),
    ))

    # Metastatic stem (turtle 1): same position, heading 90
    new_entity!(world, (
        TumorPosition(stem0_x, stem0_y),
        TumorHeading(90.0),
        TumorAge(0),
        StemCell(),
        MetastaticTag(),
    ))

    stats.cell_count = 2
    return nothing
end

# --- Update ---
# Each tick, process all EXISTING turtles in random order (newly hatched excluded).
# Per turtle:
#   1. If metastatic stem and xcor < 25 → fd 1
#   2. age += 1
#   3. If non-stem: move-transitional-cells (fd 1, hatch if age < 6)
#   4. If stem: mitosis (hatch 1 non-stem cell)
#   5. Death check

mutable struct TumorUpdateSystem <: System
    current_entities::Vector{Tuple{Entity, Bool, Bool}}  # (eid, is_stem, is_metastatic)
    to_spawn::Vector{Tuple{Float64, Float64, Float64, Int, Bool}}  # (x, y, heading, age, metastatic)
    to_remove::Vector{Entity}
end
TumorUpdateSystem() = TumorUpdateSystem(
    Tuple{Entity, Bool, Bool}[],
    Tuple{Float64, Float64, Float64, Int, Bool}[],
    Entity[],
)

function update!(system::TumorUpdateSystem, world::World)
    params = get_resource(world, TumorParams)
    rng = get_resource(world, RNGResource).rng
    wf = Float64(params.grid_width)
    hf = Float64(params.grid_height)

    # NetLogo xcor=25 in [0,103) space: 25 + 51.5 = 76.5
    xcor_threshold = 76.5

    empty!(system.current_entities)
    empty!(system.to_spawn)
    empty!(system.to_remove)

    # Collect current entities by archetype (snapshot — newly spawned excluded)
    for (eids, _) in Query(world, (TumorPosition,); with=(StemCell, MetastaticTag))
        @inbounds for i in eachindex(eids)
            push!(system.current_entities, (eids[i], true, true))
        end
    end
    for (eids, _) in Query(world, (TumorPosition,); with=(StemCell,), without=(MetastaticTag,))
        @inbounds for i in eachindex(eids)
            push!(system.current_entities, (eids[i], true, false))
        end
    end
    for (eids, _) in Query(world, (TumorPosition,); with=(MetastaticTag,), without=(StemCell,))
        @inbounds for i in eachindex(eids)
            push!(system.current_entities, (eids[i], false, true))
        end
    end
    for (eids, _) in Query(world, (TumorPosition,); without=(StemCell, MetastaticTag))
        @inbounds for i in eachindex(eids)
            push!(system.current_entities, (eids[i], false, false))
        end
    end

    # Random order (NetLogo ask turtles)
    shuffle!(rng, system.current_entities)

    for (eid, is_stem, is_meta) in system.current_entities
        is_alive(world, eid) || continue

        pos = get_components(world, eid, (TumorPosition,))[1]
        hdg = get_components(world, eid, (TumorHeading,))[1]
        age_c = get_components(world, eid, (TumorAge,))[1]

        # 1. Metastatic stem movement
        if is_stem && is_meta && pos.x < xcor_threshold
            θ = deg2rad(hdg.angle)
            pos.x = mod(pos.x + sin(θ), wf)
            pos.y = mod(pos.y + cos(θ), hf)
        end

        # 2. Age
        age_c.age += 1

        # 3. Transitional cell movement & division
        if !is_stem
            # fd 1
            θ = deg2rad(hdg.angle)
            pos.x = mod(pos.x + sin(θ), wf)
            pos.y = mod(pos.y + cos(θ), hf)

            # Hatch if young (age < 6, but age was just incremented, so check age < 6)
            if age_c.age < 6
                new_heading = rand(rng) * 360.0
                nθ = deg2rad(new_heading)
                nx = mod(pos.x + sin(nθ), wf)
                ny = mod(pos.y + cos(nθ), hf)
                push!(system.to_spawn, (nx, ny, new_heading, age_c.age, is_meta))
            end
        end

        # 4. Mitosis (stem cells)
        if is_stem
            θ = deg2rad(hdg.angle)
            nx = mod(pos.x + sin(θ), wf)
            ny = mod(pos.y + cos(θ), hf)
            # New cell: non-stem, age 0, inherits metastatic from parent
            push!(system.to_spawn, (nx, ny, hdg.angle, 0, is_meta))
        end

        # 5. Death
        if !is_stem
            if !is_meta && age_c.age > 20
                push!(system.to_remove, eid)
            elseif is_meta && age_c.age > 4
                push!(system.to_remove, eid)
            end
        end
    end

    # Spawn new cells
    for (x, y, heading, age, meta) in system.to_spawn
        if meta
            new_entity!(world, (
                TumorPosition(x, y),
                TumorHeading(heading),
                TumorAge(age),
                MetastaticTag(),
            ))
        else
            new_entity!(world, (
                TumorPosition(x, y),
                TumorHeading(heading),
                TumorAge(age),
            ))
        end
    end

    # Remove dead cells
    for e in system.to_remove
        is_alive(world, e) && remove_entity!(world, e)
    end
    return nothing
end

# --- Stats ---

struct TumorStatsSystem <: System end

function update!(::TumorStatsSystem, world::World)
    stats = get_resource(world, TumorStats)
    count = 0
    for (eids, _) in Query(world, (TumorPosition,))
        count += length(eids)
    end
    stats.cell_count = count
    return nothing
end

# --- Termination ---

struct TumorTerminationSystem <: System end

function update!(::TumorTerminationSystem, world::World)
    params = get_resource(world, TumorParams)
    tick = get_resource(world, Tick)
    stats = get_resource(world, TumorStats)
    if stats.cell_count <= 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
