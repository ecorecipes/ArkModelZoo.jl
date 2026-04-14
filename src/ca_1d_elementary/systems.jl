struct InitCA1DSystem <: System end

function _ca1d_rule_bit(rule::Int, left::Bool, center::Bool, right::Bool)
    idx = (left ? 4 : 0) + (center ? 2 : 0) + (right ? 1 : 0)
    return (rule >> idx) & 1 == 1
end

function initialize!(::InitCA1DSystem, world::World)
    params = get_resource(world, CA1DParams)
    rng = get_resource(world, RNGResource).rng
    g = get_resource(world, CA1DGrid)
    stats = get_resource(world, CA1DStats)

    fill!(g.cells, false)
    stats.current_row = 1

    # Initialize first row
    if params.random_init
        for x in 1:g.width
            g.cells[x, 1] = rand(rng, Float64) * 100.0 < params.density
        end
    else
        mid = div(g.width, 2) + 1
        g.cells[mid, 1] = true
    end

    _ca1d_update_stats!(world)
    return nothing
end

struct CA1DGoSystem <: System end

function update!(::CA1DGoSystem, world::World)
    params = get_resource(world, CA1DParams)
    g = get_resource(world, CA1DGrid)
    stats = get_resource(world, CA1DStats)
    row = stats.current_row

    row >= g.height && return nothing

    # Apply rule to current row, write to next row (wrapping at edges)
    next_row = row + 1
    w = g.width
    for x in 1:w
        left = g.cells[mod1(x - 1, w), row]
        center = g.cells[x, row]
        right = g.cells[mod1(x + 1, w), row]
        g.cells[x, next_row] = _ca1d_rule_bit(params.rule, left, center, right)
    end

    stats.current_row = next_row
    _ca1d_update_stats!(world)
    return nothing
end

function _ca1d_update_stats!(world::World)
    g = get_resource(world, CA1DGrid)
    stats = get_resource(world, CA1DStats)
    total_on = 0
    total_cells = 0
    for row in 1:stats.current_row, x in 1:g.width
        total_cells += 1
        if g.cells[x, row]
            total_on += 1
        end
    end
    stats.density_on = total_cells > 0 ? total_on / total_cells : 0.0
end

struct CA1DTerminationSystem <: System end

function update!(::CA1DTerminationSystem, world::World)
    params = get_resource(world, CA1DParams)
    g = get_resource(world, CA1DGrid)
    stats = get_resource(world, CA1DStats)
    tick = get_resource(world, Tick)
    if stats.current_row >= g.height || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
