mutable struct PartyGroupSites
    sites::Vector{Int}          # x-coordinates of group sites (1-based grid coords)
    group_interval::Int
    world_width::Int
end

function PartyGroupSites(world_width::Int, num_groups::Int)
    group_interval = div(world_width, num_groups)
    # NetLogo: pxcor <= 0, pxcor mod group_interval == 0, floor(-pxcor / group_interval) < num_groups
    # In NetLogo coords: x = 0, -interval, -2*interval, ...
    # Map to 1-based: NetLogo x=-80..1, so 1-based offset = x + 81
    # x=0 → col 81, x=-8 → col 73, ... x=-72 → col 9
    sites = Int[]
    for i in 0:(num_groups - 1)
        nl_x = -i * group_interval  # NetLogo x-coordinate
        col = nl_x + world_width    # 1-based column (world_width = 82, so x=0 → col=82)
        push!(sites, col)
    end
    PartyGroupSites(sites, group_interval, world_width)
end

mutable struct PartyStats
    boring_groups::Int
end
PartyStats() = PartyStats(0)
