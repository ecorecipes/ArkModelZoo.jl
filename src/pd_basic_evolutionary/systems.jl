# --- Initialization ---

struct InitPDESystem <: System end

function initialize!(::InitPDESystem, world::World)
    params = get_resource(world, PDEParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, PDEGrid)
    w, h = grid.width, grid.height

    for x in 1:w, y in 1:h
        c = rand(rng) < (params.initial_cooperation / 100.0)
        grid.cooperate[x, y] = c
        grid.old_cooperate[x, y] = c
    end

    _pde_update_stats!(world)
    return nothing
end

# --- Go: interact + select-strategy ---

struct PDEGoSystem <: System end

function update!(::PDEGoSystem, world::World)
    params = get_resource(world, PDEParams)
    grid = get_resource(world, PDEGrid)
    w, h = grid.width, grid.height

    # interact: compute scores
    for x in 1:w, y in 1:h
        total_cooperators = 0
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = mod1(x + dx, w)
            ny = mod1(y + dy, h)
            if grid.cooperate[nx, ny]
                total_cooperators += 1
            end
        end
        if grid.cooperate[x, y]
            grid.score[x, y] = Float64(total_cooperators)
        else
            grid.score[x, y] = params.defection_award * total_cooperators
        end
    end

    # select-strategy: copy old, then adopt neighbor's strategy with max score
    copyto!(grid.old_cooperate, grid.cooperate)

    for x in 1:w, y in 1:h
        best_score = -Inf
        best_coop = grid.cooperate[x, y]
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = mod1(x + dx, w)
            ny = mod1(y + dy, h)
            if grid.score[nx, ny] > best_score
                best_score = grid.score[nx, ny]
                best_coop = grid.cooperate[nx, ny]
            end
        end
        grid.cooperate[x, y] = best_coop
    end

    _pde_update_stats!(world)
    return nothing
end

function _pde_update_stats!(world::World)
    grid = get_resource(world, PDEGrid)
    stats = get_resource(world, PDEStats)
    w, h = grid.width, grid.height

    nc = 0; nd = 0; cc = 0; dd = 0; cd = 0; dc = 0
    for x in 1:w, y in 1:h
        old_c = grid.old_cooperate[x, y]
        new_c = grid.cooperate[x, y]
        if new_c
            nc += 1
        else
            nd += 1
        end
        if old_c && new_c
            cc += 1
        elseif !old_c && !new_c
            dd += 1
        elseif old_c && !new_c
            cd += 1
        else
            dc += 1
        end
    end
    stats.num_cooperators = nc
    stats.num_defectors = nd
    stats.num_cc = cc
    stats.num_dd = dd
    stats.num_cd = cd
    stats.num_dc = dc
    return nothing
end

# --- Termination ---

struct PDETerminationSystem <: System end

function update!(::PDETerminationSystem, world::World)
    params = get_resource(world, PDEParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
