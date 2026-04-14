# --- Initialization ---

struct InitSSSystem <: System end

function initialize!(::InitSSSystem, world::World)
    params = get_resource(world, SSParams)
    rng = get_resource(world, RNGResource).rng
    ssworld = get_resource(world, SSWorld)
    stats = get_resource(world, SSStats)
    w, h = ssworld.width, ssworld.height

    # Load landscape: row 1 of matrix = top (y=h), row h = bottom (y=1)
    for x in 1:w, y in 1:h
        val = SS_SUGAR_LANDSCAPE[h + 1 - y, x]
        ssworld.max_psugar[x, y] = val
        ssworld.psugar[x, y] = val
    end

    # Create agents at random unoccupied patches
    for _ in 1:params.initial_population
        # Find an unoccupied patch
        px, py = rand(rng, 1:w), rand(rng, 1:h)
        while ssworld.occupant[px, py] != 0
            px, py = rand(rng, 1:w), rand(rng, 1:h)
        end
        sug = Float64(rand(rng, 50:100))
        met = rand(rng, 1:4)
        vis = rand(rng, 1:6)
        sexo = rand(rng, 0:1)
        muerte = 60 + rand(rng, 0:39)
        fertilidadc = 12 + rand(rng, 0:2)
        fertilidadf = sexo == 1 ? 50 + rand(rng, 0:9) : 40 + rand(rng, 0:9)
        agent = SSAgent(px, py, sug, met, vis, sexo, 0, muerte, fertilidadc, fertilidadf, sug, true)
        push!(ssworld.agents, agent)
        ssworld.occupant[px, py] = length(ssworld.agents)
    end

    stats.num_turtles = length(ssworld.agents)
    return nothing
end

# --- Main Go System ---

struct SSGoSystem <: System end

function update!(::SSGoSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    ssworld = get_resource(world, SSWorld)
    stats = get_resource(world, SSStats)
    w, h = ssworld.width, ssworld.height
    agents = ssworld.agents

    # If no alive agents → terminate
    nalive = count(a -> a.alive, agents)
    if nalive == 0
        get_resource(world, Terminate).stop = true
        return nothing
    end

    # Growback
    for x in 1:w, y in 1:h
        if ssworld.psugar[x, y] < ssworld.max_psugar[x, y]
            ssworld.psugar[x, y] = min(ssworld.max_psugar[x, y], ssworld.psugar[x, y] + 1)
        end
    end

    # Process agents in shuffled order (snapshot of current alive agents)
    alive_indices = [i for i in 1:length(agents) if agents[i].alive]
    Random.shuffle!(rng, alive_indices)

    for idx in alive_indices
        agent = agents[idx]
        !agent.alive && continue

        # Move
        _ss_move!(agent, ssworld, rng, idx)

        # Eat
        agent.sugar = agent.sugar - agent.metabolism + ssworld.psugar[agent.x, agent.y]
        ssworld.psugar[agent.x, agent.y] = 0

        # Death: sugar
        if agent.sugar <= 0
            agent.alive = false
            ssworld.occupant[agent.x, agent.y] = 0
            continue
        end

        # Death: age
        if agent.edad == agent.muerte
            agent.alive = false
            ssworld.occupant[agent.x, agent.y] = 0
            continue
        end

        # Age
        agent.edad += 1

        # Reproduction
        if agent.edad >= agent.fertilidadc && agent.edad <= agent.fertilidadf && agent.sugar >= agent.dotacion
            _ss_sexear!(agent, ssworld, rng, idx)
        end
    end

    # Compact: remove dead agents, rebuild occupant grid
    filter!(a -> a.alive, agents)
    _ss_rebuild_occupant!(ssworld)

    stats.num_turtles = length(agents)
    return nothing
end

# --- Movement: vision-based cardinal search ---

function _ss_move!(agent::SSAgent, ssworld::SSWorld, rng, agent_idx::Int)
    w, h = ssworld.width, ssworld.height
    best_sugar = -1
    best_dist = w + h
    candidates = Tuple{Int,Int}[]

    for (dx, dy) in ((0, 1), (1, 0), (0, -1), (-1, 0))
        for d in 1:agent.vision
            nx = mod1(agent.x + dx * d, w)
            ny = mod1(agent.y + dy * d, h)
            ssworld.occupant[nx, ny] != 0 && continue
            s = ssworld.psugar[nx, ny]
            if s > best_sugar || (s == best_sugar && d < best_dist)
                best_sugar = s
                best_dist = d
                empty!(candidates)
                push!(candidates, (nx, ny))
            elseif s == best_sugar && d == best_dist
                push!(candidates, (nx, ny))
            end
        end
    end

    isempty(candidates) && return

    cx, cy = candidates[rand(rng, 1:length(candidates))]
    ssworld.occupant[agent.x, agent.y] = 0
    ssworld.occupant[cx, cy] = agent_idx
    agent.x = cx
    agent.y = cy
end

# --- Reproduction ---

function _ss_sexear!(agent::SSAgent, ssworld::SSWorld, rng, agent_idx::Int)
    w, h = ssworld.width, ssworld.height
    agents = ssworld.agents
    dirs = ((0, 1), (1, 0), (0, -1), (-1, 0))

    # Find neighbor4 agents of opposite sex
    neighbor_indices = Int[]
    for (dx, dy) in dirs
        nx = mod1(agent.x + dx, w)
        ny = mod1(agent.y + dy, h)
        occ = ssworld.occupant[nx, ny]
        if occ > 0 && agents[occ].alive && agents[occ].sexo != agent.sexo
            push!(neighbor_indices, occ)
        end
    end

    Random.shuffle!(rng, neighbor_indices)

    for ni in neighbor_indices
        neighbor = agents[ni]

        # Check neighbor fertility
        neighbor.alive || continue
        (neighbor.edad >= neighbor.fertilidadc && neighbor.edad <= neighbor.fertilidadf && neighbor.sugar >= neighbor.dotacion) || continue

        # Re-check self fertility (sugar may have dropped from prior birth)
        (agent.sugar >= agent.dotacion) || return

        born = false
        birth_x, birth_y = 0, 0

        # Try from neighbor's side
        for (dx, dy) in dirs
            born && break
            bx = mod1(neighbor.x + dx, w)
            by = mod1(neighbor.y + dy, h)
            if ssworld.occupant[bx, by] == 0
                birth_x, birth_y = bx, by
                born = true
            end
        end

        # Try from own side
        if !born
            for (dx, dy) in dirs
                born && break
                bx = mod1(agent.x + dx, w)
                by = mod1(agent.y + dy, h)
                if ssworld.occupant[bx, by] == 0
                    birth_x, birth_y = bx, by
                    born = true
                end
            end
        end

        if born
            child_metabolism = rand(rng, Bool) ? agent.metabolism : neighbor.metabolism
            child_vision = rand(rng, Bool) ? agent.vision : neighbor.vision
            child_sexo = rand(rng, 0:1)
            child_muerte = 60 + rand(rng, 0:39)
            child_fertilidadc = 12 + rand(rng, 0:2)
            child_fertilidadf = child_sexo == 1 ? 50 + rand(rng, 0:9) : 40 + rand(rng, 0:9)
            child_sugar = agent.dotacion / 2.0 + neighbor.dotacion / 2.0
            child_dotacion = child_sugar

            child = SSAgent(
                birth_x, birth_y,
                child_sugar, child_metabolism, child_vision,
                child_sexo, 0, child_muerte,
                child_fertilidadc, child_fertilidadf,
                child_dotacion, true,
            )

            push!(agents, child)
            ssworld.occupant[birth_x, birth_y] = length(agents)

            # Parents pay sugar cost
            agent.sugar -= agent.dotacion / 2.0
            neighbor.sugar -= neighbor.dotacion / 2.0
        end
    end
end

# --- Rebuild occupant grid ---

function _ss_rebuild_occupant!(ssworld::SSWorld)
    fill!(ssworld.occupant, 0)
    for (i, agent) in enumerate(ssworld.agents)
        if agent.alive
            ssworld.occupant[agent.x, agent.y] = i
        end
    end
end

# --- Termination ---

struct SSTerminationSystem <: System end

function update!(::SSTerminationSystem, world::World)
    params = get_resource(world, SSParams)
    tick = get_resource(world, Tick)
    ssworld = get_resource(world, SSWorld)
    nalive = count(a -> a.alive, ssworld.agents)
    if nalive == 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
