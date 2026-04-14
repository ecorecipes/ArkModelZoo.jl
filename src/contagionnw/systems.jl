# Contagion on Network (Preferential Attachment)
# NetLogo: grows network via preferential attachment, then spreads contagion

struct InitContagionNWSystem <: System end

function initialize!(::InitContagionNWSystem, world::World)
    params = get_resource(world, ContagionNWParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, CNWNetwork)
    stats = get_resource(world, CNWStats)

    # NetLogo setup: make-node nobody; make-node turtle 0
    # Start with 2 nodes connected by 1 link, N=1
    _cnw_add_node!(net)  # node 1
    _cnw_add_node!(net)  # node 2
    _cnw_add_edge!(net, 1, 2)

    # NetLogo go: while [N < number-of-links] grow network
    # N starts at 1 (from second make-node), increments each make-node call
    link_count = 1
    while link_count < params.number_of_links
        # find-partner: [one-of both-ends] of one-of links
        # Pick a random edge, then pick one end
        total_links = _cnw_num_links(net)
        if total_links == 0
            break
        end
        # Flatten edges for uniform random pick
        target_idx = rand(rng, 1:total_links)
        edge_count = 0
        partner = 1
        found = false
        for i in 1:net.n
            for j in net.adj[i]
                j > i || continue  # count each edge once
                edge_count += 1
                if edge_count == target_idx
                    partner = rand(rng, (i, j))
                    found = true
                    break
                end
            end
            found && break
        end

        # make-node: create turtle, link to partner, N += 1
        new_id = _cnw_add_node!(net)
        _cnw_add_edge!(net, new_id, partner)
        link_count += 1
    end

    # All turtles start red (uninfected); mark all as not infected initially
    # NetLogo: after growth loop, ask one-of turtles [set color green]
    if net.n > 0
        initial = rand(rng, 1:net.n)
        net.infected[initial] = true
    end

    stats.num_infected = count(net.infected)
    stats.num_links = _cnw_num_links(net)
    return nothing
end

struct CNWSpreadSystem <: System end

function update!(::CNWSpreadSystem, world::World)
    params = get_resource(world, ContagionNWParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, CNWNetwork)
    stats = get_resource(world, CNWStats)

    # NetLogo go (after growth):
    # ask one-of turtles [set color green]  — pick one turtle to start spreading from
    # if any? turtles with [color = red] — if uninfected exist
    #   ask turtles with [color = green] — each infected turtle
    #     ask link-neighbors — linked neighbors
    #       if random 100 <= probability-linked-affected [set color green]
    #       ask other turtles — ALL other turtles (non-link)
    #         if random 100 < probability-other-affected [set color green]
    #
    # NOTE: The NetLogo code has nested ask: for each infected turtle,
    # for each link-neighbor, it asks ALL other turtles. This is unusual
    # but faithful to the original. We implement the effect:
    # infected turtles try to infect link-neighbors with p_linked,
    # and also try to infect all non-link turtles with p_other.

    any_uninfected = any(!, net.infected)
    if !any_uninfected
        return nothing
    end

    new_infected = copy(net.infected)

    # Shuffle infected indices (NetLogo ask shuffles)
    infected_ids = findall(net.infected)
    Random.shuffle!(rng, infected_ids)

    for i in infected_ids
        # Try to infect link-neighbors
        neighbors = collect(net.adj[i])
        Random.shuffle!(rng, neighbors)
        for j in neighbors
            if !new_infected[j]
                if rand(rng, 0:99) <= params.probability_linked_affected
                    new_infected[j] = true
                end
            end
            # Each link-neighbor also triggers asks to "other turtles" 
            # For efficiency, we just do the other-turtles pass once per infected
        end
        # Try to infect all other (non-link) turtles with lower probability
        for j in 1:net.n
            j == i && continue
            j in net.adj[i] && continue
            if !new_infected[j]
                if rand(rng, 0:99) < params.probability_other_affected
                    new_infected[j] = true
                end
            end
        end
    end

    copy!(net.infected, new_infected)
    stats.num_infected = count(net.infected)
    stats.num_links = _cnw_num_links(net)
    return nothing
end

struct CNWTerminationSystem <: System end

function update!(::CNWTerminationSystem, world::World)
    params = get_resource(world, ContagionNWParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
