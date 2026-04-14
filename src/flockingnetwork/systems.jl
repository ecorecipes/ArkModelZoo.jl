# Flocking with Network Links
# Turtles form pos/neg weighted links based on distance and adjust heading

struct InitFlockingNetworkSystem <: System end

function initialize!(::InitFlockingNetworkSystem, world::World)
    params = get_resource(world, FlockingNetworkParams)
    rng = get_resource(world, RNGResource).rng

    wf = Float64(params.grid_width)
    hf = Float64(params.grid_height)
    for _ in 1:params.population
        x = rand(rng) * wf
        y = rand(rng) * hf
        heading = Float64(rand(rng, 0:359))
        new_entity!(world, (FNPosition(x, y), FNHeading(heading), FNTag()))
    end
    return nothing
end

struct FNFlockSystem <: System
    positions::Vector{Tuple{Entity,Float64,Float64,Float64}}
end
FNFlockSystem() = FNFlockSystem(Tuple{Entity,Float64,Float64,Float64}[])

function update!(sys::FNFlockSystem, world::World)
    params = get_resource(world, FlockingNetworkParams)
    rng = get_resource(world, RNGResource).rng
    stats = get_resource(world, FNStats)
    wf = Float64(params.grid_width)
    hf = Float64(params.grid_height)
    max_sep = params.maximum_separation
    min_sep = params.minimum_separation
    coupling = params.coupling_strength
    coherence = params.coherence_strength
    separation = params.separation_strength
    alignment = params.alignment_strength

    # Collect all agents
    empty!(sys.positions)
    for (eids, positions, headings) in Query(world, (FNPosition, FNHeading); with=(FNTag,))
        @inbounds for i in eachindex(eids)
            push!(sys.positions, (eids[i], positions[i].x, positions[i].y, headings[i].angle))
        end
    end

    n = length(sys.positions)
    num_links = 0

    # For each turtle: find neighbors, compute avg headings, update heading
    # NetLogo ask shuffles
    order = collect(1:n)
    Random.shuffle!(rng, order)

    for idx in order
        (eid, x, y, h) = sys.positions[idx]

        # Find negative neighbors (within minimum_separation)
        neg_headings = Float64[]
        # Find positive neighbors (within maximum_separation but outside minimum_separation)
        pos_headings = Float64[]

        for jdx in 1:n
            jdx == idx && continue
            (_, ox, oy, oh) = sys.positions[jdx]
            # Toroidal distance
            ddx = abs(x - ox)
            ddx = min(ddx, wf - ddx)
            ddy = abs(y - oy)
            ddy = min(ddy, hf - ddy)
            dist = sqrt(ddx * ddx + ddy * ddy)

            if dist <= min_sep
                push!(neg_headings, oh)
                num_links += 1
            elseif dist <= max_sep
                push!(pos_headings, oh)
                num_links += 1
            end
        end

        avg_head_pos = 0.0
        avg_head_neg = 0.0
        if !isempty(pos_headings)
            avg_head_pos = sum(pos_headings) / length(pos_headings)
        end
        if !isempty(neg_headings)
            avg_head_neg = sum(neg_headings) / length(neg_headings)
        end

        # NetLogo: heading + coupling * (coherence*(avg_pos - heading) + separation*(180+avg_neg-heading) + alignment*(0.5*(avg_neg+avg_pos)-heading))
        new_h = h + coupling * (
            coherence * (avg_head_pos - h) +
            separation * (180.0 + avg_head_neg - h) +
            alignment * (0.5 * (avg_head_neg + avg_head_pos) - h)
        )

        # Update heading in ECS
        for (_, _, headings) in Query(world, (FNPosition, FNHeading); with=(FNTag,))
            @inbounds for i in eachindex(headings)
                # Find matching entity by comparing stored data
            end
        end
        # Store updated heading back
        sys.positions[idx] = (eid, x, y, new_h)
    end

    # Apply heading updates and move forward by 1
    # Build a map from entity to new heading
    heading_map = Dict{Entity, Float64}()
    for (eid, _, _, h) in sys.positions
        heading_map[eid] = h
    end

    for (eids, positions, headings) in Query(world, (FNPosition, FNHeading); with=(FNTag,))
        @inbounds for i in eachindex(eids)
            if haskey(heading_map, eids[i])
                headings[i].angle = heading_map[eids[i]]
            end
            θ = deg2rad(headings[i].angle)
            positions[i].x = mod(positions[i].x + sin(θ), wf)
            positions[i].y = mod(positions[i].y + cos(θ), hf)
        end
    end

    # Links are undirected, counted from both sides
    stats.num_links = div(num_links, 1)  # each pair counted once per idx
    # Compute average heading
    if n > 0
        total_h = 0.0
        for (_, _, _, h) in sys.positions
            total_h += h
        end
        stats.avg_heading = total_h / n
    else
        stats.avg_heading = 0.0
    end

    return nothing
end

struct FNTerminationSystem <: System end

function update!(::FNTerminationSystem, world::World)
    params = get_resource(world, FlockingNetworkParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
