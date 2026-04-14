# --- Initialization ---
# NetLogo: create one tree per cell with random species 0..14, then update-richness

struct InitFDSystem <: System end

function initialize!(::InitFDSystem, world::World)
    params = get_resource(world, FDParams)
    rng = get_resource(world, RNGResource).rng
    forest = get_resource(world, FDForest)
    stats = get_resource(world, FDStats)

    empty!(forest.trees)
    for y in 1:params.grid_height, x in 1:params.grid_width
        push!(forest.trees, FDTree(x, y, rand(rng, 0:params.num_species - 1)))
    end

    # update-richness: count unique species
    stats.local_richness = length(Set(t.species for t in forest.trees))
    stats.sp = 0
    return nothing
end

# --- Go (ingest + reproduce + update-richness) ---
# NetLogo per tick:
#   ingest-process: pick random tree candidate, record sp = species.
#     If count trees with that species > 1, kill it and record x-cor, y-cor.
#     Retry up to 100 times if species count <= 1.
#   reproduce-process: pick random tree, hatch copy at (last_x, last_y).
#   update-richness: count unique species.

struct FDGoSystem <: System end

function update!(::FDGoSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    forest = get_resource(world, FDForest)
    stats = get_resource(world, FDStats)

    # --- ingest-process ---
    victim_idx = 0
    attempts = 0
    while victim_idx == 0 && attempts < 100
        idx = rand(rng, 1:length(forest.trees))
        candidate = forest.trees[idx]
        stats.sp = candidate.species
        n = count(t -> t.species == candidate.species, forest.trees)
        if n > 1
            victim_idx = idx
        end
        attempts += 1
    end

    if victim_idx != 0
        victim = forest.trees[victim_idx]
        forest.last_x = victim.x
        forest.last_y = victim.y
        # Remove victim (swap-remove for efficiency)
        forest.trees[victim_idx] = forest.trees[end]
        pop!(forest.trees)
    end

    # --- reproduce-process ---
    if !isempty(forest.trees)
        parent = forest.trees[rand(rng, 1:length(forest.trees))]
        push!(forest.trees, FDTree(forest.last_x, forest.last_y, parent.species))
    end

    # --- update-richness ---
    stats.local_richness = length(Set(t.species for t in forest.trees))

    return nothing
end

# --- Termination ---

struct FDTerminationSystem <: System end

function update!(::FDTerminationSystem, world::World)
    params = get_resource(world, FDParams)
    tick = get_resource(world, Tick)

    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
