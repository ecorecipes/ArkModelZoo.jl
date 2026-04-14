# --- Initialization ---

struct InitPERCSystem <: System end

function initialize!(::InitPERCSystem, world::World)
    grid = get_resource(world, PERCGrid)
    # Set up top row: odd x-positions in row 1 become leading edge (red)
    grid.current_row = 1
    for x in 1:grid.width
        if x % 2 == 0  # NetLogo: pxcor mod 2 = 1 (0-indexed), our 1-indexed: x%2==0
            if grid.cells[x, 1] == PERC_PERM
                grid.cells[x, 1] = PERC_EDGE
            end
        end
    end
    _perc_update_stats!(world)
    return nothing
end

function _perc_update_stats!(world::World)
    grid = get_resource(world, PERCGrid)
    stats = get_resource(world, PERCStats)
    edge_count = 0
    for x in 1:grid.width
        if grid.current_row >= 1 && grid.current_row <= grid.height
            if grid.cells[x, grid.current_row] == PERC_EDGE
                edge_count += 1
            end
        end
    end
    stats.leading_edge_count = edge_count
    stats.total_oil = grid.total_oil
end

# --- Go ---

struct PERCGoSystem <: System end

function update!(::PERCGoSystem, world::World)
    params = get_resource(world, PERCParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, PERCGrid)
    w, h = grid.width, grid.height
    row = grid.current_row

    # Check if any red cells in current row
    has_edge = false
    for x in 1:w
        if row >= 1 && row <= h && grid.cells[x, row] == PERC_EDGE
            has_edge = true
            break
        end
    end

    if !has_edge
        get_resource(world, Terminate).stop = true
        _perc_update_stats!(world)
        return nothing
    end

    # Percolate: each red cell tries to spread to two cells below (diagonally)
    next_row = row + 1
    if next_row <= h
        for x in 1:w
            if grid.cells[x, row] == PERC_EDGE
                # Try southwest (-1, +1) and southeast (+1, +1)
                for dx in [-1, 1]
                    nx = x + dx
                    if nx >= 1 && nx <= w
                        if grid.cells[nx, next_row] == PERC_PERM
                            if rand(rng) * 100.0 < params.porosity
                                grid.cells[nx, next_row] = PERC_EDGE
                            end
                        end
                    end
                end
                grid.cells[x, row] = PERC_SAT
                grid.total_oil += 1
            end
        end
        grid.current_row = next_row
    else
        # Wrap: move bottom to top (camera pan)
        for x in 1:w
            if grid.cells[x, row] == PERC_EDGE
                grid.cells[x, row] = PERC_SAT
                grid.total_oil += 1
            end
        end
        # Copy the state of the row that would be "below" to the top
        # Reset grid and continue from top
        new_top = Matrix{Int}(undef, w, h)
        for x in 1:w, y in 1:h
            new_top[x, y] = (x + y) % 2 == 0 ? PERC_HARD : PERC_PERM
        end
        # Keep current_row's edge info at top
        for x in 1:w
            if row <= h && grid.cells[x, row] == PERC_SAT
                # The row below (wrapped) keeps its state
            end
        end
        grid.cells = new_top
        grid.current_row = 1
        # Check if anything to continue
        has_new_edge = false
        for x in 1:w
            if grid.cells[x, 1] == PERC_EDGE
                has_new_edge = true
                break
            end
        end
        if !has_new_edge
            get_resource(world, Terminate).stop = true
        end
    end

    _perc_update_stats!(world)
    return nothing
end

# --- Termination ---

struct PERCTerminationSystem <: System end

function update!(::PERCTerminationSystem, world::World)
    params = get_resource(world, PERCParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
