# --- Initialization ---

struct InitPartySystem <: System end

function initialize!(::InitPartySystem, world::World)
    params = get_resource(world, PartyParams)
    rng = get_resource(world, RNGResource).rng
    gs = get_resource(world, PartyGroupSites)
    stats = get_resource(world, PartyStats)

    # Create turtles: random sex, random group site
    for _ in 1:params.number
        sex = rand(rng, 0:1)  # 0=pink(female), 1=blue(male)
        site_idx = rand(rng, 1:length(gs.sites))
        new_entity!(world, (
            PartySex(sex),
            PartyState(true, site_idx),
            PartyTag(),
        ))
    end

    # Initial happiness
    _party_update_happiness!(world)
    _party_count_boring!(world)
    return nothing
end

# --- Update Happiness ---
# For each turtle, count same-sex and opposite-sex at its group site.
# happy if opposite/total <= tolerance/100

function _party_update_happiness!(world::World)
    params = get_resource(world, PartyParams)
    gs = get_resource(world, PartyGroupSites)
    n_sites = length(gs.sites)

    # Count pink and blue at each site
    pink_count = zeros(Int, n_sites)
    blue_count = zeros(Int, n_sites)

    for (_, sexes, states) in Query(world, (PartySex, PartyState); with=(PartyTag,))
        @inbounds for i in eachindex(sexes)
            si = states[i].my_group_site
            if sexes[i].sex == 0
                pink_count[si] += 1
            else
                blue_count[si] += 1
            end
        end
    end

    # Update happiness
    for (_, sexes, states) in Query(world, (PartySex, PartyState); with=(PartyTag,))
        @inbounds for i in eachindex(sexes)
            si = states[i].my_group_site
            total = pink_count[si] + blue_count[si]
            if total == 0
                states[i].happy = true
            else
                if sexes[i].sex == 0  # pink
                    same = pink_count[si]
                else
                    same = blue_count[si]
                end
                opposite = total - same
                states[i].happy = (opposite / total) <= (params.tolerance / 100.0)
            end
        end
    end
end

# --- Count Boring Groups ---
# A group is boring if all turtles there are the same color (length of unique colors == 1)
# Empty groups are NOT boring

function _party_count_boring!(world::World)
    gs = get_resource(world, PartyGroupSites)
    stats = get_resource(world, PartyStats)
    n_sites = length(gs.sites)

    has_pink = falses(n_sites)
    has_blue = falses(n_sites)

    for (_, sexes, states) in Query(world, (PartySex, PartyState); with=(PartyTag,))
        @inbounds for i in eachindex(sexes)
            si = states[i].my_group_site
            if sexes[i].sex == 0
                has_pink[si] = true
            else
                has_blue[si] = true
            end
        end
    end

    boring = 0
    for si in 1:n_sites
        occupied = has_pink[si] || has_blue[si]
        mixed = has_pink[si] && has_blue[si]
        if occupied && !mixed
            boring += 1
        end
    end
    stats.boring_groups = boring
end

# --- Party Update System ---
# go: move-to my-group-site; update-happiness; leave-if-unhappy; find-new-groups; count-boring

struct PartyUpdateSystem <: System end

function update!(::PartyUpdateSystem, world::World)
    params = get_resource(world, PartyParams)
    rng = get_resource(world, RNGResource).rng
    gs = get_resource(world, PartyGroupSites)
    n_sites = length(gs.sites)

    # Turtles are already at their group sites (my_group_site tracks assignment).
    # Update happiness (uses current group assignments)
    _party_update_happiness!(world)

    # leave-if-unhappy: unhappy turtles pick heading 90 or 270, move to adjacent group site
    # find-new-groups is recursive: keeps moving displaced turtles until at a group site.
    # Since turtles only track group site indices, we compute the next group directly.
    # Heading 90 (east) → site with higher x → lower site index (sites are ordered 0, -8, -16, ...)
    #   Actually sites[1] = x=0 (col 82), sites[2] = x=-8 (col 74), etc.
    #   East from sites[1] wraps to sites[10] (since wrapping world).
    #   West from sites[1] goes to sites[2].
    # heading 270 (west) → next site to west → higher index
    # heading 90 (east) → next site to east → lower index (wrapping)

    for (eids, sexes, states) in Query(world, (PartySex, PartyState); with=(PartyTag,))
        indices = collect(eachindex(states))
        Random.shuffle!(rng, indices)
        @inbounds for i in indices
            if !states[i].happy
                dir = rand(rng, 0:1)  # 0 = east (heading 90), 1 = west (heading 270)
                si = states[i].my_group_site
                if dir == 0
                    # East: decrease site index (wrap around)
                    new_si = si == 1 ? n_sites : si - 1
                else
                    # West: increase site index (wrap around)
                    new_si = si == n_sites ? 1 : si + 1
                end
                states[i].my_group_site = new_si
            end
        end
    end

    _party_count_boring!(world)
    return nothing
end

# --- Stats System ---

struct PartyStatsSystem <: System end

function update!(::PartyStatsSystem, world::World)
    # Stats are already updated in PartyUpdateSystem
    return nothing
end

# --- Termination ---

struct PartyTerminationSystem <: System end

function update!(::PartyTerminationSystem, world::World)
    params = get_resource(world, PartyParams)
    tick = get_resource(world, Tick)

    # Check if all turtles are happy
    all_happy = true
    for (_, _, states) in Query(world, (PartySex, PartyState); with=(PartyTag,))
        @inbounds for i in eachindex(states)
            if !states[i].happy
                all_happy = false
                break
            end
        end
        !all_happy && break
    end

    if all_happy || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
