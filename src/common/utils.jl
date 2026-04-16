# ── Shared utilities for ArkModelZoo models ──────────────────────────

# ── Model boilerplate helpers ────────────────────────────────────────

"""
    _add_standard_resources!(world, params)

Add the 4 standard resources every model needs: Tick(0), Terminate(false),
RNGResource(Xoshiro(params.seed)), and a deep copy of params.
"""
function _add_standard_resources!(world::World, params)
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    if hasproperty(params, :seed)
        add_resource!(world, RNGResource(Xoshiro(params.seed)))
    end
    add_resource!(world, deepcopy(params))
end

"""
    _run_model(model_fn, observer, values_fn; params, observe=true)

Generic run loop used by all models. Creates the scheduler via `model_fn(params)`,
then steps until termination, collecting trajectory via `values_fn(observer, world)`.
"""
function _run_model(model_fn, observer, values_fn; params, observe::Bool = true)
    scheduler = model_fn(params)
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, values_fn(observer, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, values_fn(observer, scheduler.world))
        end
    end
    return scheduler, trajectory
end

_model_sort_key(spec::ModelSpec) = (
    get(MODEL_CATEGORY_INDEX, spec.category, typemax(Int)),
    lowercase(spec.title),
)

function _normalize_model_key(name::Union{AbstractString,Symbol})
    return _normalize_model_lookup_key(name)
end

"""
    model_categories() -> Vector{String}

Return the supported high-level model categories in the same order used by the
generated vignette index.
"""
model_categories() = collect(MODEL_CATEGORY_ORDER)

"""
    model_catalog(; category=nothing) -> Vector{ModelSpec}

Return metadata for every public ArkModelZoo model. Pass `category` to filter
the catalog to a single top-level grouping such as `"Biology & Ecology"`.
"""
function model_catalog(; category::Union{Nothing,AbstractString} = nothing)
    specs = category === nothing ?
        collect(MODEL_SPECS) :
        [spec for spec in MODEL_SPECS if spec.category == category]
    sort!(specs; by = _model_sort_key)
    return specs
end

"""
    model_info(name) -> ModelSpec

    Look up one model by canonical name (`"sir"`), human-typed variants
(`"rabbits grass weeds"`), NetLogo wrapper names (`"simple_birth_rates"`),
or exported runner (`"run_rgw"`).
"""
function model_info(name::Union{AbstractString,Symbol})
    key = _normalize_model_key(name)
    spec = get(MODEL_SPEC_LOOKUP, key, nothing)
    spec === nothing &&
        error("Unknown model '$name'. Use available_models() or model_catalog() to inspect the catalog.")
    return spec
end

"""
    run_model(name; params=nothing, observe=true)

Run one ArkModelZoo model by catalog name, human-typed variant, or NetLogo-style
wrapper name without needing to know the exact exported `run_*` symbol.
"""
function run_model(name::Union{AbstractString,Symbol}; params=nothing, observe::Bool = true)
    spec = model_info(name)
    run_fn = getfield(@__MODULE__, spec.run_symbol)
    params === nothing && return run_fn(; observe)
    return run_fn(; params, observe)
end

"""
    available_models(; category=nothing) -> Vector{String}

Return the sorted list of public model names that can be run via the exported
`run_*` entry points. Pass `category` to restrict the result to one section of
the catalog.
"""
function available_models(; category::Union{Nothing,AbstractString} = nothing)
    return sort!([spec.name for spec in model_catalog(; category)])
end

# ── Spatial / patch utilities ────────────────────────────────────────

"""
    moore_neighbors_wrap(x, y, w, h) -> Vector{Tuple{Int,Int}}

Return the 8 toroidal Moore neighbor coordinates of `(x, y)` on a `w × h` grid.
"""
function moore_neighbors_wrap(x::Int, y::Int, w::Int, h::Int)
    nbrs = Tuple{Int,Int}[]
    for dx in -1:1, dy in -1:1
        (dx == 0 && dy == 0) && continue
        push!(nbrs, (mod1(x + dx, w), mod1(y + dy, h)))
    end
    return nbrs
end

"""
    moore_neighbors_bounded(x, y, w, h) -> Vector{Tuple{Int,Int}}

Return the Moore neighbor coordinates of `(x, y)` clipped to grid bounds.
"""
function moore_neighbors_bounded(x::Int, y::Int, w::Int, h::Int)
    nbrs = Tuple{Int,Int}[]
    for dx in -1:1, dy in -1:1
        (dx == 0 && dy == 0) && continue
        nx, ny = x + dx, y + dy
        if 1 <= nx <= w && 1 <= ny <= h
            push!(nbrs, (nx, ny))
        end
    end
    return nbrs
end

"""
    moore_neighbor_sum(field, x, y, w, h)

Sum the 8 Moore neighbors of `(x, y)` in `field` with toroidal wrapping.
"""
function moore_neighbor_sum(field::AbstractMatrix, x::Int, y::Int, w::Int, h::Int)
    s = zero(eltype(field))
    @inbounds for dx in -1:1, dy in -1:1
        (dx == 0 && dy == 0) && continue
        s += field[mod1(x + dx, w), mod1(y + dy, h)]
    end
    return s
end

"""
    moore_neighbor_count(pred, field, x, y, w, h)

Count Moore neighbors of `(x, y)` satisfying `pred(value)`, toroidal wrapping.
"""
function moore_neighbor_count(pred, field::AbstractMatrix, x::Int, y::Int, w::Int, h::Int)
    n = 0
    @inbounds for dx in -1:1, dy in -1:1
        (dx == 0 && dy == 0) && continue
        pred(field[mod1(x + dx, w), mod1(y + dy, h)]) && (n += 1)
    end
    return n
end

"""
    diffuse!(field, fraction, w, h)

NetLogo-style `diffuse` on a toroidal grid. Each patch gives `fraction` of its
value equally to its 8 Moore neighbors.
"""
function diffuse!(field::Matrix{Float64}, fraction::Float64, w::Int, h::Int)
    old = copy(field)
    share = fraction / 8.0
    keep = 1.0 - fraction
    @inbounds for x in 1:w, y in 1:h
        field[x, y] = keep * old[x, y]
    end
    @inbounds for x in 1:w, y in 1:h
        contrib = old[x, y] * share
        contrib == 0.0 && continue
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            field[mod1(x + dx, w), mod1(y + dy, h)] += contrib
        end
    end
    return nothing
end

"""
    diffuse_bounded!(field, fraction, w, h)

NetLogo-style `diffuse` on a bounded (non-wrapping) grid.
"""
function diffuse_bounded!(field::Matrix{Float64}, fraction::Float64, w::Int, h::Int)
    old = copy(field)
    share = fraction / 8.0
    @inbounds for x in 1:w, y in 1:h
        give = old[x, y] * share
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx, ny = x + dx, y + dy
            (nx < 1 || nx > w || ny < 1 || ny > h) && continue
            field[nx, ny] += give
        end
        field[x, y] -= old[x, y] * fraction
    end
    return nothing
end

# ── NetLogo-style heading movement ──────────────────────────────────
# Convention: 0=north, 90=east, clockwise degrees.
# dx = sin(heading°), dy = cos(heading°).

"""
    netlogo_dx(heading) -> Float64

X displacement for a heading in NetLogo degrees (0=north, 90=east).
"""
netlogo_dx(heading::Float64) = sin(heading * π / 180.0)

"""
    netlogo_dy(heading) -> Float64

Y displacement for a heading in NetLogo degrees.
"""
netlogo_dy(heading::Float64) = cos(heading * π / 180.0)

"""
    netlogo_forward(x, y, heading, dist, w, h) -> (nx, ny)

Move forward `dist` at `heading` on a toroidal grid of size `w × h`.
Uses continuous (Float64) coordinates with `mod1` wrapping.
"""
function netlogo_forward(x::Float64, y::Float64, heading::Float64, dist::Float64, w::Int, h::Int)
    θ = heading * π / 180.0
    nx = mod(x + sin(θ) * dist - 1.0, Float64(w)) + 1.0
    ny = mod(y + cos(θ) * dist - 1.0, Float64(h)) + 1.0
    return nx, ny
end

"""
    netlogo_towards(x1, y1, x2, y2) -> heading

Heading from (x1,y1) to (x2,y2) in NetLogo degrees (non-wrapping).
"""
function netlogo_towards(x1::Float64, y1::Float64, x2::Float64, y2::Float64)
    dx = x2 - x1
    dy = y2 - y1
    (dx == 0.0 && dy == 0.0) && return 0.0
    return mod(atan(dx, dy) * 180.0 / π, 360.0)
end

"""
    netlogo_towards_wrap(x1, y1, x2, y2, w, h) -> heading

Heading from (x1,y1) to (x2,y2) via shortest toroidal path.
"""
function netlogo_towards_wrap(x1::Float64, y1::Float64, x2::Float64, y2::Float64, w::Int, h::Int)
    dx = x2 - x1
    dy = y2 - y1
    fw = Float64(w)
    fh = Float64(h)
    if abs(dx) > fw / 2; dx = dx > 0 ? dx - fw : dx + fw; end
    if abs(dy) > fh / 2; dy = dy > 0 ? dy - fh : dy + fh; end
    (dx == 0.0 && dy == 0.0) && return 0.0
    return mod(atan(dx, dy) * 180.0 / π, 360.0)
end

"""
    netlogo_distance(x1, y1, x2, y2) -> Float64

Euclidean distance (non-wrapping).
"""
netlogo_distance(x1::Float64, y1::Float64, x2::Float64, y2::Float64) =
    sqrt((x2 - x1)^2 + (y2 - y1)^2)

"""
    netlogo_distance_wrap(x1, y1, x2, y2, w, h) -> Float64

Toroidal Euclidean distance (shortest path on torus).
"""
function netlogo_distance_wrap(x1::Float64, y1::Float64, x2::Float64, y2::Float64, w::Int, h::Int)
    dx = abs(x2 - x1)
    dy = abs(y2 - y1)
    fw = Float64(w)
    fh = Float64(h)
    if dx > fw / 2; dx = fw - dx; end
    if dy > fh / 2; dy = fh - dy; end
    return sqrt(dx^2 + dy^2)
end

"""
    wiggle(rng, heading, max_angle) -> new_heading

Random heading perturbation: `rt random(max_angle) lt random(max_angle)`.
"""
function wiggle(rng::AbstractRNG, heading::Float64, max_angle::Float64)
    return mod(heading + rand(rng) * max_angle - rand(rng) * max_angle, 360.0)
end
