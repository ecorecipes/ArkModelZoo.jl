# --- Initialization ---

struct InitVoronoiVoterSystem <: System end

function initialize!(::InitVoronoiVoterSystem, world::World)
    params = get_resource(world, VoronoiVoterParams)
    rng = get_resource(world, RNGResource).rng
    vgrid = get_resource(world, VoronoiGrid)
    network = get_resource(world, VoronoiNetwork)
    stats = get_resource(world, VoronoiStats)
    w, h = vgrid.width, vgrid.height

    # Create points as entities and store references by index
    point_entities = Entity[]
    point_xs = Float64[]
    point_ys = Float64[]
    for i in 1:params.n_points
        x = rand(rng) * w
        y = rand(rng) * h
        color_id = rand(rng, 1:params.n_palette)
        e = new_entity!(world, (VoterPoint(x, y, color_id),))
        push!(point_entities, e)
        push!(point_xs, x)
        push!(point_ys, y)
    end

    # Assign each patch to nearest point (Voronoi tessellation)
    for px in 1:w, py in 1:h
        best_idx = 1
        best_dist = Inf
        for i in 1:params.n_points
            dx = abs(Float64(px) - point_xs[i])
            dy = abs(Float64(py) - point_ys[i])
            dx = min(dx, w - dx)
            dy = min(dy, h - dy)
            d = dx * dx + dy * dy
            if d < best_dist
                best_dist = d
                best_idx = i
            end
        end
        vgrid.owner[px, py] = best_idx
    end

    # Compute adjacency: two points are neighbors if their Voronoi cells share adjacent patches
    for i in 1:params.n_points
        network.neighbors[i] = Int[]
    end
    for px in 1:w, py in 1:h
        owner_idx = vgrid.owner[px, py]
        for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1))
            nx = mod1(px + dx, w)
            ny = mod1(py + dy, h)
            nbr_idx = vgrid.owner[nx, ny]
            if nbr_idx != owner_idx && !(nbr_idx in network.neighbors[owner_idx])
                push!(network.neighbors[owner_idx], nbr_idx)
            end
        end
    end

    # Count distinct colors
    colors_set = Set{Int}()
    for i in 1:params.n_points
        vp = get_components(world, point_entities[i], (VoterPoint,))[1]
        push!(colors_set, vp.color_id)
    end
    stats.n_colors = length(colors_set)

    # Store entity list in a resource for fast indexed access
    add_resource!(world, VoronoiEntityList(point_entities))

    return nothing
end

# Entity list resource for indexed access
mutable struct VoronoiEntityList
    entities::Vector{Entity}
end

# --- Voter Update ---

struct VoronoiVoterUpdateSystem <: System end

function update!(::VoronoiVoterUpdateSystem, world::World)
    params = get_resource(world, VoronoiVoterParams)
    rng = get_resource(world, RNGResource).rng
    network = get_resource(world, VoronoiNetwork)
    elist = get_resource(world, VoronoiEntityList)
    n = params.n_points

    for _ in 1:n
        idx = rand(rng, 1:n)
        nbrs = network.neighbors[idx]
        isempty(nbrs) && continue
        nbr_idx = nbrs[rand(rng, 1:length(nbrs))]
        vp_nbr = get_components(world, elist.entities[nbr_idx], (VoterPoint,))[1]
        vp = get_components(world, elist.entities[idx], (VoterPoint,))[1]
        vp.color_id = vp_nbr.color_id
    end
    return nothing
end

# --- Stats ---

struct VoronoiStatsSystem <: System end

function update!(::VoronoiStatsSystem, world::World)
    stats = get_resource(world, VoronoiStats)
    elist = get_resource(world, VoronoiEntityList)
    world_ref = world
    colors_set = Set{Int}()
    for e in elist.entities
        vp = get_components(world_ref, e, (VoterPoint,))[1]
        push!(colors_set, vp.color_id)
    end
    stats.n_colors = length(colors_set)
    return nothing
end

# --- Termination ---

struct VoronoiTerminationSystem <: System end

function update!(::VoronoiTerminationSystem, world::World)
    stats = get_resource(world, VoronoiStats)
    params = get_resource(world, VoronoiVoterParams)
    tick = get_resource(world, Tick)
    if stats.n_colors <= 1 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
