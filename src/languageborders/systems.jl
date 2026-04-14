# --- Initialization ---

struct InitLanguageBordersSystem <: System end

function initialize!(::InitLanguageBordersSystem, world::World)
    params = get_resource(world, LanguageBordersParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, LanguageBordersGrid)
    stats = get_resource(world, LanguageBordersStats)
    w, h = grid.width, grid.height

    # pycor = y - 1 (y=1 → pycor=0, y=h → pycor=h-1=40)
    # boundary: pycor > initial_percent_green * (h-1) → blue (Language=105)
    boundary_y = params.initial_percent_green * (h - 1)  # 0.5 * 40 = 20.0
    for x in 1:w, y in 1:h
        pycor = y - 1
        grid.language[x, y] = pycor > boundary_y ? 105.0 : 55.0
        # ability = round(random-normal(normal_mean, 1)), clamped >= 0
        raw = randn(rng) + params.normal_mean
        grid.ability[x, y] = max(0, round(Int, raw))
    end

    stats.avg_language = Statistics.mean(grid.language)
    return nothing
end

# --- Update ---
# Each tick: ask patches (random order) to update language via neighbor averaging.
# Non-wrapping Moore neighborhood.
# precision(x, n) = round(x * 10^n) / 10^n

struct LanguageBordersUpdateSystem <: System end

function update!(::LanguageBordersUpdateSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, LanguageBordersGrid)
    stats = get_resource(world, LanguageBordersStats)
    w, h = grid.width, grid.height
    language = grid.language
    ability = grid.ability

    # Random patch order (sequential Gauss-Seidel update)
    indices = Vector{Tuple{Int,Int}}(undef, w * h)
    k = 0
    for x in 1:w, y in 1:h
        k += 1
        indices[k] = (x, y)
    end
    Random.shuffle!(rng, indices)

    for (x, y) in indices
        sum_lang = 0.0
        count = 0
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = x + dx
            ny = y + dy
            if 1 <= nx <= w && 1 <= ny <= h
                sum_lang += language[nx, ny]
                count += 1
            end
        end
        neighbor_av = count > 0 ? sum_lang / count : language[x, y]
        my_average = (neighbor_av + language[x, y]) / 2.0
        a = ability[x, y]
        scale = 10.0^a
        language[x, y] = round(my_average * scale) / scale
    end

    stats.avg_language = Statistics.mean(language)
    return nothing
end

# --- Termination ---

struct LanguageBordersTerminationSystem <: System end

function update!(::LanguageBordersTerminationSystem, world::World)
    params = get_resource(world, LanguageBordersParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
