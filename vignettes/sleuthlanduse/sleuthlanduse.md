# Sleuth LandUse


- [Overview](#overview)
- [Parameters](#parameters)
- [Source Code](#source-code)
- [Appendix: Source Code](#appendix-source-code)
  - [Parameters (`parameters.jl`)](#parameters-parametersjl)
  - [Components (`components.jl`)](#components-componentsjl)
  - [Resources (`resources.jl`)](#resources-resourcesjl)
  - [Systems (`systems.jl`)](#systems-systemsjl)
  - [Model (`model.jl`)](#model-modeljl)

## Overview

This vignette demonstrates the **Sleuth LandUse** model implemented in
[ArkModelZoo.jl](https://github.com/sdwfrost/ArkModelZoo.jl) using the
Ark.jl ECS framework.

## Parameters

| Parameter     | Type      | Default | Description |
|---------------|-----------|---------|-------------|
| `data_dir`    | `String`  | `"."`   | data dir    |
| `lobby`       | `Float64` | `1.0`   | lobby       |
| `dispersion`  | `Float64` | `52.0`  | dispersion  |
| `newspread`   | `Float64` | `55.0`  | newspread   |
| `spread`      | `Float64` | `26.0`  | spread      |
| `rounds`      | `Int`     | `50`    | rounds      |
| `grid_width`  | `Int`     | `753`   | grid width  |
| `grid_height` | `Int`     | `753`   | grid height |
| `max_ticks`   | `Int`     | `50`    | max ticks   |

## Source Code

The Julia code to run this model:

``` julia
using ArkModelZoo
_, trajectory = run_sleuthlanduse()
```

## Appendix: Source Code

This model is implemented in the
[Ark.jl](https://github.com/sdwfrost/Ark.jl) Entity-Component-System
(ECS) framework. The code is split into five files, each with a distinct
role:

- **Parameters**: a mutable struct holding all configurable values.
- **Components**: lightweight data types attached to individual entities
  (agents).
- **Resources**: world-level shared state accessible to all systems.
- **Systems**: functions that operate on entities each tick, defining
  model behavior.
- **Model**: wiring that assembles the world, registers resources and
  systems, and provides the run entry point.

### Parameters (`parameters.jl`)

The parameter struct uses `@kwdef` so that every field has a default
value and can be overridden by keyword. These defaults match the
original NetLogo model’s slider settings.

``` julia
Base.@kwdef mutable struct SleuthParams
    data_dir::String = "."
    lobby::Float64 = 1.0
    dispersion::Float64 = 52.0
    newspread::Float64 = 55.0
    spread::Float64 = 26.0
    rounds::Int = 50
    grid_width::Int = 753
    grid_height::Int = 753
    max_ticks::Int = 50
    seed::Int = 42
end
```

### Components (`components.jl`)

Components are lightweight data types attached to individual entities
(agents). Mutable structs hold per-entity state, while empty tag structs
act as markers for the ECS query system to efficiently filter entities.

``` julia
struct SleuthDummy end
```

### Resources (`resources.jl`)

Resources are world-level singletons shared across all systems, used for
global state and aggregate statistics.

``` julia
# County IDs used in the model
const SLEUTH_COUNTY_IDS = [1, 2, 10, 12, 14, 18, 20, 24, 26, 28, 29, 32, 35, 36, 37, 40, 41, 42, 43, 44, 46, 49, 56]

mutable struct SleuthGrid
    width::Int
    height::Int
    urban::Matrix{Float64}
    county::Matrix{Float64}
    excluded::Matrix{Float64}
    road::Matrix{Float64}
    available::Matrix{Bool}
    capdist::Matrix{Float64}
    county_urban::Dict{Int,Int}     # county_id => urban count
    county_total::Dict{Int,Int}     # county_id => total patch count
end

function SleuthGrid(w::Int, h::Int)
    SleuthGrid(w, h,
        zeros(Float64, w, h),
        zeros(Float64, w, h),
        zeros(Float64, w, h),
        zeros(Float64, w, h),
        falses(w, h),
        zeros(Float64, w, h),
        Dict{Int,Int}(),
        Dict{Int,Int}())
end

mutable struct SleuthStats
    urbantotal::Int
    purbantotal::Float64
    concentration::Float64
end
SleuthStats() = SleuthStats(0, 0.0, 0.0)
```

### Systems (`systems.jl`)

Systems contain the model logic and execute in a defined order each
tick. Each system struct implements either `initialize!` (run once at
setup) or `update!` (run every tick).

``` julia
# --- Initialization ---

struct InitSleuthSystem <: System end

function initialize!(::InitSleuthSystem, world::World)
    params = get_resource(world, SleuthParams)
    grid = get_resource(world, SleuthGrid)
    stats = get_resource(world, SleuthStats)
    w, h = grid.width, grid.height

    # Load 4 raster layers
    urban_r = gis_load_asc(joinpath(params.data_dir, "urbandclr3.asc"))
    county_r = gis_load_asc(joinpath(params.data_dir, "countyls.asc"))
    excluded_r = gis_load_asc(joinpath(params.data_dir, "excludedlr.asc"))
    road_r = gis_load_asc(joinpath(params.data_dir, "rasterroad.asc"))

    # Use common envelope and resample to model grid size
    env = gis_envelope(urban_r)
    half_w = div(w, 2)
    half_h = div(h, 2)
    transform = gis_set_world_envelope(env, -half_w, half_w, -half_h, half_h)

    grid.urban = gis_apply_raster(urban_r, w, h, transform)
    grid.county = gis_apply_raster(county_r, w, h, transform)
    grid.excluded = gis_apply_raster(excluded_r, w, h, transform)
    grid.road = gis_apply_raster(road_r, w, h, transform)

    nodata = urban_r.nodata

    # Calculate centroid of county 43
    cx43, cy43, n43 = 0.0, 0.0, 0
    for x in 1:w, y in 1:h
        cval = grid.county[x, y]
        if cval != nodata && round(Int, cval) == 43
            cx43 += x; cy43 += y; n43 += 1
        end
    end
    if n43 > 0
        cx43 /= n43; cy43 /= n43
    else
        cx43 = w / 2.0; cy43 = h / 2.0
    end

    # Calculate capdist and determine availability, county counts
    for cid in SLEUTH_COUNTY_IDS
        grid.county_urban[cid] = 0
        grid.county_total[cid] = 0
    end

    for x in 1:w, y in 1:h
        grid.capdist[x, y] = sqrt((x - cx43)^2 + (y - cy43)^2)
        cval = grid.county[x, y]
        cid = (cval == nodata || cval < 0) ? 0 : round(Int, cval)
        # Urban raster: 2 = urbanized, 1 = rural, -9999 = nodata
        uval = grid.urban[x, y]
        is_urban = uval != nodata && uval >= 2.0
        # Excluded raster: 1 = excluded, -9999 = nodata
        eval_v = grid.excluded[x, y]
        is_excluded = eval_v != nodata && eval_v >= 1.0
        in_valid_county = cid > 0 && cid < 57

        grid.available[x, y] = in_valid_county && !is_excluded && !is_urban

        if in_valid_county && cid in SLEUTH_COUNTY_IDS
            grid.county_total[cid] = get(grid.county_total, cid, 0) + 1
            if is_urban
                grid.county_urban[cid] = get(grid.county_urban, cid, 0) + 1
            end
        end
    end

    _update_sleuth_stats!(grid, stats)
    return nothing
end

function _update_sleuth_stats!(grid::SleuthGrid, stats::SleuthStats)
    w, h = grid.width, grid.height
    total_urban = 0
    total_patches = 0
    nodata = -9999.0

    # Recount county urban/total
    for cid in SLEUTH_COUNTY_IDS
        grid.county_urban[cid] = 0
        grid.county_total[cid] = 0
    end

    for x in 1:w, y in 1:h
        cval = grid.county[x, y]
        cid = (cval == nodata || cval < 0) ? 0 : round(Int, cval)
        if cid > 0 && cid < 57
            total_patches += 1
            uval = grid.urban[x, y]
            is_urban = uval != nodata && uval >= 2.0
            if is_urban
                total_urban += 1
            end
            if cid in SLEUTH_COUNTY_IDS
                grid.county_total[cid] = get(grid.county_total, cid, 0) + 1
                if is_urban
                    grid.county_urban[cid] = get(grid.county_urban, cid, 0) + 1
                end
            end
        end
    end

    stats.urbantotal = total_urban
    stats.purbantotal = total_patches > 0 ? total_urban / total_patches : 0.0

    # Herfindahl concentration index
    hhi = 0.0
    for cid in SLEUTH_COUNTY_IDS
        cu = get(grid.county_urban, cid, 0)
        if total_urban > 0
            share = cu / total_urban
            hhi += share^2
        end
    end
    stats.concentration = hhi
    return nothing
end

function _get_tax(grid::SleuthGrid, x::Int, y::Int, lobby::Float64)
    cval = grid.county[x, y]
    cid = (cval == -9999.0 || cval < 0) ? 0 : round(Int, cval)
    cu = get(grid.county_urban, cid, 0)
    ct = get(grid.county_total, cid, 0)
    pct_urban = ct > 0 ? cu / ct : 0.0
    return pct_urban * lobby * 100.0
end

# Wrapping helper
function _wrap(v::Int, lo::Int, hi::Int)
    r = hi - lo + 1
    return mod(v - lo, r) + lo
end

# --- Growth System ---

struct SleuthGrowthSystem <: System end

function update!(::SleuthGrowthSystem, world::World)
    params = get_resource(world, SleuthParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, SleuthGrid)
    w, h = grid.width, grid.height

    # Spontaneous growth
    for _ in 1:params.rounds
        x = rand(rng, 1:w)
        y = rand(rng, 1:h)
        if !grid.available[x, y]
            continue
        end
        tax = _get_tax(grid, x, y, params.lobby)
        threshold = params.dispersion * 5.3 * (100.0 - tax) / 100.0
        if rand(rng) * 100.0 < threshold
            # Urbanize
            grid.urban[x, y] = 2.0
            grid.available[x, y] = false

            # Spread to up to 2 neighbors
            spread_count = 0
            for _ in 1:8
                spread_count >= 2 && break
                dx = rand(rng, -1:1)
                dy = rand(rng, -1:1)
                (dx == 0 && dy == 0) && continue
                nx = _wrap(x + dx, 1, w)
                ny = _wrap(y + dy, 1, h)
                if grid.available[nx, ny]
                    ntax = _get_tax(grid, nx, ny, params.lobby)
                    if rand(rng) * 100.0 < params.newspread * (100.0 - ntax) / 100.0
                        grid.urban[nx, ny] = 2.0
                        grid.available[nx, ny] = false
                        spread_count += 1
                    end
                end
            end
        end
    end

    # Edge growth: available patches with >= 3 urban neighbors urbanize
    to_urbanize = Tuple{Int,Int}[]
    for x in 1:w, y in 1:h
        if !grid.available[x, y]
            continue
        end
        urban_neighbors = 0
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = _wrap(x + dx, 1, w)
            ny = _wrap(y + dy, 1, h)
            if grid.urban[nx, ny] >= 2.0
                urban_neighbors += 1
            end
        end
        if urban_neighbors >= 3
            tax = _get_tax(grid, x, y, params.lobby)
            if rand(rng) * 100.0 < params.spread * (100.0 - tax) / 100.0
                push!(to_urbanize, (x, y))
            end
        end
    end
    for (x, y) in to_urbanize
        grid.urban[x, y] = 2.0
        grid.available[x, y] = false
    end

    return nothing
end

# --- Stats Update ---

struct SleuthStatsSystem <: System end

function update!(::SleuthStatsSystem, world::World)
    grid = get_resource(world, SleuthGrid)
    stats = get_resource(world, SleuthStats)
    _update_sleuth_stats!(grid, stats)
    return nothing
end

# --- Termination ---

struct SleuthTerminationSystem <: System end

function update!(::SleuthTerminationSystem, world::World)
    params = get_resource(world, SleuthParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
```

### Model (`model.jl`)

The model file assembles all pieces: it creates the ECS `World` with the
required component types, registers resources, builds the `Scheduler`
with systems in execution order, and exposes the public `run` entry
point. The observer pattern records the trajectory each tick.

``` julia
function sleuthlanduse_world(; initial_capacity::Int = 128)
    return World(
        SleuthDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function sleuthlanduse_systems()
    return (
        InitSleuthSystem(),
        SleuthGrowthSystem(),
        SleuthStatsSystem(),
        SleuthTerminationSystem(),
    )
end

function sleuthlanduse_model(params::SleuthParams = SleuthParams())
    world = sleuthlanduse_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SleuthGrid(params.grid_width, params.grid_height))
    add_resource!(world, SleuthStats())
    scheduler = Scheduler(world, sleuthlanduse_systems())
    initialize!(scheduler)
    return scheduler
end

struct SleuthObserver end

function sleuthlanduse_headers(::SleuthObserver)
    return ["UrbanTotal", "PctUrban", "Concentration"]
end

function sleuthlanduse_values(::SleuthObserver, world::World)
    stats = get_resource(world, SleuthStats)
    return Float64[stats.urbantotal, stats.purbantotal, stats.concentration]
end

function run_sleuthlanduse(; params::SleuthParams = SleuthParams(), observe::Bool = true)
    return _run_model(sleuthlanduse_model, SleuthObserver(), sleuthlanduse_values; params, observe)
end
```
