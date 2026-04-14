# --- Initialization ---

struct InitNormSystem <: System end

function initialize!(::InitNormSystem, world::World)
    params = get_resource(world, NormParams)
    rng = get_resource(world, RNGResource).rng

    for _ in 1:params.turtle_count
        new_entity!(world, (NormAgent(rand(rng, 0:7), rand(rng, 0:7), 0.0, 0.0),))
    end
    return nothing
end

# --- Interaction ---
# Each turtle repeats 4 rounds. May defect, others may punish/meta-punish.
# Points are modified in real-time. seen? is a turtle-own used as observation probability.

mutable struct NormInteractionSystem <: System
    entities::Vector{Tuple{Entity, Int}}  # (eid, index into agents array)
    agents::Vector{NormAgent}             # cached references
    agent_eids::Vector{Entity}            # all entity IDs
end
NormInteractionSystem() = NormInteractionSystem(
    Tuple{Entity, Int}[], NormAgent[], Entity[],
)

function update!(system::NormInteractionSystem, world::World)
    params = get_resource(world, NormParams)
    rng = get_resource(world, RNGResource).rng
    stats = get_resource(world, NormStats)
    stats.defections = 0

    # Collect all agents into a flat array for O(1) random access
    empty!(system.agents)
    empty!(system.agent_eids)
    for (eids, agents) in Query(world, (NormAgent,))
        @inbounds for i in eachindex(agents)
            push!(system.agents, agents[i])
            push!(system.agent_eids, eids[i])
        end
    end

    n = length(system.agents)
    n == 0 && return nothing

    # Random order for outer ask
    order = randperm(rng, n)

    for idx in order
        agent = system.agents[idx]

        for _ in 1:4
            punishcount = 0
            metapunishcount = 0
            agent.seen = rand(rng)

            if agent.seen < agent.boldness / 7.0
                # Defect: gain 3 points
                agent.points += 3.0
                stats.defections += 1

                # ask other turtles (random order)
                other_order = randperm(rng, n)
                for oidx in other_order
                    oidx == idx && continue  # skip self

                    other = system.agents[oidx]
                    other.points -= 1.0  # all others lose 1

                    # Observation: uses OTHER turtle's seen value
                    if rand(rng) < other.seen
                        punish_roll = rand(rng)
                        if other.vengefulness / 7.0 > punish_roll
                            # Punish
                            punishcount += 1
                            other.points -= 2.0
                        else
                            # Non-punisher may get meta-punished
                            if params.metanorm
                                metapunishcount = 0
                                # ask other turtles of the non-punisher
                                meta_order = randperm(rng, n)
                                for midx in meta_order
                                    midx == oidx && continue  # skip non-punisher
                                    meta_agent = system.agents[midx]
                                    if rand(rng) < meta_agent.seen
                                        metapunishcount += 1
                                        meta_agent.points -= 2.0
                                    end
                                end
                                other.points -= 9.0 * metapunishcount
                            end
                        end
                    end
                end
                agent.points -= 9.0 * punishcount
            end
        end
    end
    return nothing
end

# --- Reproduction ---
# All turtles die. High fitness → hatch 2, medium → 1, low → 0.
# Population adjusted to turtle_count. Then 1% mutation.

mutable struct NormReproductionSystem <: System
    offspring::Vector{Tuple{Int, Int, Float64}}  # (boldness, vengefulness, seen)
end
NormReproductionSystem() = NormReproductionSystem(Tuple{Int, Int, Float64}[])

function update!(system::NormReproductionSystem, world::World)
    params = get_resource(world, NormParams)
    rng = get_resource(world, RNGResource).rng
    stats = get_resource(world, NormStats)

    # Collect agents and compute stats
    agents = NormAgent[]
    eids = Entity[]
    for (es, avs) in Query(world, (NormAgent,))
        @inbounds for i in eachindex(avs)
            push!(agents, avs[i])
            push!(eids, es[i])
        end
    end

    n = length(agents)
    n == 0 && return nothing

    points = [a.points for a in agents]
    mn = sum(points) / n
    sd = n > 1 ? sqrt(sum((p - mn)^2 for p in points) / (n - 1)) : 0.0

    # NetLogo uses population std dev (not sample), but let's check:
    # standard-deviation in NetLogo uses N-1 denominator (sample std dev)
    # Actually, NetLogo standard-deviation uses N-1. So the above is correct.
    stats.mean_points = mn
    stats.sd_points = sd

    empty!(system.offspring)

    # Process in random order (ask turtles)
    order = randperm(rng, n)
    for idx in order
        a = agents[idx]
        if a.points >= mn + sd
            push!(system.offspring, (a.boldness, a.vengefulness, a.seen))
            push!(system.offspring, (a.boldness, a.vengefulness, a.seen))
        elseif a.points >= mn - sd
            push!(system.offspring, (a.boldness, a.vengefulness, a.seen))
        end
        # All turtles die (handled below)
    end

    # Remove all current turtles
    for e in eids
        is_alive(world, e) && remove_entity!(world, e)
    end

    # Spawn offspring (inherit seen from parent, as NetLogo hatch inherits turtle-owns)
    for (b, v, s) in system.offspring
        new_entity!(world, (NormAgent(b, v, 0.0, s),))
    end

    # Adjust population to turtle_count
    current_count = length(system.offspring)
    diff = params.turtle_count - current_count

    if diff < 0
        # Too many: kill newest (highest who → last spawned)
        new_eids = Entity[]
        for (es, _) in Query(world, (NormAgent,))
            @inbounds for i in eachindex(es)
                push!(new_eids, es[i])
            end
        end
        # Remove from end (newest entities)
        for _ in 1:(-diff)
            isempty(new_eids) && break
            e = pop!(new_eids)
            is_alive(world, e) && remove_entity!(world, e)
        end
    elseif diff > 0
        # Too few: add random agents
        for _ in 1:diff
            new_entity!(world, (NormAgent(rand(rng, 0:7), rand(rng, 0:7), 0.0, 0.0),))
        end
    end

    # 1% mutation on boldness and vengefulness
    for (_, avs) in Query(world, (NormAgent,))
        @inbounds for i in eachindex(avs)
            if rand(rng) <= 0.01
                avs[i].boldness = rand(rng, 0:7)
            end
            if rand(rng) <= 0.01
                avs[i].vengefulness = rand(rng, 0:7)
            end
        end
    end
    return nothing
end

# --- Stats (computed in reproduction) ---

struct NormStatsSystem <: System end
function update!(::NormStatsSystem, world::World)
    return nothing
end

# --- Termination ---

struct NormTerminationSystem <: System end

function update!(::NormTerminationSystem, world::World)
    params = get_resource(world, NormParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
