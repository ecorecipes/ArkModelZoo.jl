# --- Initialization ---

struct InitPolymerSystem <: System end

function initialize!(::InitPolymerSystem, world::World)
    params = get_resource(world, PolymerDynamicsParams)
    pgrid = get_resource(world, PolymerGrid)
    stats = get_resource(world, PolymerStats)

    # NetLogo coords: x=0..159, y=0..79; Julia 1-indexed: x=1..160, y=1..80
    # Turtles at pycor = round(79/2) = 40, pxcor in 1..158
    turtle_y = 41  # pycor 40 → Julia y 41

    for pxcor in 1:158
        jx = pxcor + 1  # NetLogo pxcor 1..158 → Julia 1-indexed (pxcor 0 → x=1)
        # item (pxcor mod 2) [blue orange]: 0→blue, 1→orange
        if pxcor % 2 == 0
            push!(pgrid.blue_positions, (jx, turtle_y))
        else
            push!(pgrid.orange_positions, (jx, turtle_y))
        end
        pgrid.occupancy[jx, turtle_y] = 1
    end

    # NetLogo doesn't set n-turtles in setup; it defaults to 0 until first go.
    stats.n_turtles = 0
    return nothing
end

# --- Movement helpers ---

# Direction indices: 1=N(heading 0), 2=E(heading 90), 3=S(heading 180), 4=W(heading 270)
const _POLY_DX = (0, 1, 0, -1)
const _POLY_DY = (1, 0, -1, 0)

# Breaking-chain: positions behind the turtle that would become disconnected
const _BREAK_OFFSETS = (
    ((-1, -1), (0, -1), (1, -1)),  # N: check south row
    ((-1, -1), (-1, 0), (-1, 1)),  # E: check west column
    ((-1,  1), (0,  1), (1,  1)),  # S: check north row
    ((1,  -1), (1,  0), (1,  1)),  # W: check east column
)

# Crossing-chain: positions 2 ahead that would be crossed over
const _CROSS_OFFSETS = (
    ((-1, 2), (0, 2), (1, 2)),     # N
    ((2, -1), (2, 0), (2, 1)),     # E
    ((-1, -2), (0, -2), (1, -2)),  # S
    ((-2, -1), (-2, 0), (-2, 1)),  # W
)

@inline function _poly_occupied(occ::Matrix{Int}, w::Int, h::Int, x::Int, y::Int)
    return occ[mod1(x, w), mod1(y, h)] > 0
end

function _breaking_chain(occ::Matrix{Int}, w::Int, h::Int, x::Int, y::Int, dir::Int)
    for (dx, dy) in _BREAK_OFFSETS[dir]
        if _poly_occupied(occ, w, h, x + dx, y + dy)
            return true
        end
    end
    return false
end

function _crossing_chain(occ::Matrix{Int}, w::Int, h::Int, x::Int, y::Int, dir::Int)
    for (dx, dy) in _CROSS_OFFSETS[dir]
        if _poly_occupied(occ, w, h, x + dx, y + dy)
            return true
        end
    end
    return false
end

function _move_group!(positions::Vector{Tuple{Int,Int}}, pgrid::PolymerGrid,
                      rng, order::Vector{Int})
    occ = pgrid.occupancy
    w = pgrid.width
    h = pgrid.height

    for idx in order
        x, y = positions[idx]
        dir = rand(rng, 1:4)

        if !_breaking_chain(occ, w, h, x, y, dir) &&
           !_crossing_chain(occ, w, h, x, y, dir)
            nx = mod1(x + _POLY_DX[dir], w)
            ny = mod1(y + _POLY_DY[dir], h)
            occ[x, y] -= 1
            occ[nx, ny] += 1
            positions[idx] = (nx, ny)
        end
    end
end

# --- Update ---

struct PolymerUpdateSystem <: System end

function update!(::PolymerUpdateSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    pgrid = get_resource(world, PolymerGrid)
    stats = get_resource(world, PolymerStats)

    # ask blues [move] — random order within group
    nb = length(pgrid.blue_positions)
    _move_group!(pgrid.blue_positions, pgrid, rng, randperm(rng, nb))

    # ask oranges [move] — random order within group
    no = length(pgrid.orange_positions)
    _move_group!(pgrid.orange_positions, pgrid, rng, randperm(rng, no))

    stats.n_turtles = nb + no
    return nothing
end

# --- Termination ---

struct PolymerTerminationSystem <: System end

function update!(::PolymerTerminationSystem, world::World)
    params = get_resource(world, PolymerDynamicsParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
