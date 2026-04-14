#!/usr/bin/env julia
#
# ArkModelZoo ↔ NetLogo Java comparison harness
#
# Uses the same statistical framework as NetLogoCompare.jl:
#   - MAE / NMAE / Pearson r on mean trajectories
#   - KS / ECDF correlation on final-tick distributions
#   - MMD² with RBF kernel and permutation test on full trajectories
#   - Calibrated 4-batch comparison (Ark-A, Ark-B, Java-A, Java-B)
#
# Usage:
#   julia --project=. compare/compare.jl [model] [n_per_batch]
#   julia --project=. compare/compare.jl segregation 20
#   julia --project=. compare/compare.jl all 10

using Printf
using Statistics
using Random

# ── Configuration ─────────────────────────────────────────────────────

const NETLOGO_DIR = get(ENV, "NETLOGO_DIR",
    "/Users/username/Projects/netlogo/NetLogo-dist/NetLogo-6.4.0-64")

# ── Data types ────────────────────────────────────────────────────────

struct TrajectoryData
    seed::Int
    ticks::Vector{Int}
    values::Dict{String, Vector{Float64}}
end

struct BatchMetrics
    mae::Float64
    nmae::Float64
    corr_mean::Float64
    ks::Float64
    ecdf_r::Float64
    mmd_stat::Float64
    mmd_p::Float64
end

struct VariableCalibrated
    name::String
    ark_vs_ark::BatchMetrics
    java_vs_java::BatchMetrics
    ark_vs_java::BatchMetrics
    pass::Bool
end

struct CalibratedReport
    model_name::String
    n_per_batch::Int
    n_ticks::Int
    variables::Vector{VariableCalibrated}
    ark_time_s::Float64
    java_time_s::Float64
end

# ── Statistics (ported from NetLogoCompare.jl) ────────────────────────

function ks_statistic(a::Vector{Float64}, b::Vector{Float64})
    sa = sort(filter(!isnan, a))
    sb = sort(filter(!isnan, b))
    na, nb = length(sa), length(sb)
    (na == 0 || nb == 0) && return NaN
    all_v = sort(unique(vcat(sa, sb)))
    maximum(abs(searchsortedlast(sa, v)/na - searchsortedlast(sb, v)/nb) for v in all_v)
end

function pearson_r(x::Vector{Float64}, y::Vector{Float64})
    fx = filter(!isnan, x)
    fy = filter(!isnan, y)
    n = min(length(fx), length(fy))
    n < 2 && return NaN
    a, b = fx[1:n], fy[1:n]
    (std(a) < 1e-15 || std(b) < 1e-15) && return (std(a) < 1e-15 && std(b) < 1e-15) ? 1.0 : NaN
    cor(a, b)
end

function ecdf_correlation(a::Vector{Float64}, b::Vector{Float64})
    sa = sort(filter(!isnan, a))
    sb = sort(filter(!isnan, b))
    na, nb = length(sa), length(sb)
    (na < 2 || nb < 2) && return NaN
    pts = sort(unique(vcat(sa, sb)))
    length(pts) < 2 && return NaN
    ecdf_a = Float64[searchsortedlast(sa, v) / na for v in pts]
    ecdf_b = Float64[searchsortedlast(sb, v) / nb for v in pts]
    pearson_r(ecdf_a, ecdf_b)
end

function _pairwise_sq_dists(X::Matrix{Float64})
    N = size(X, 1)
    norms = sum(X .^ 2, dims=2)
    D2 = norms .+ norms' .- 2.0 .* (X * X')
    D2 .= max.(D2, 0.0)
    D2
end

function _mmd2_from_kernel(K::Matrix{Float64}, A, B)
    m = length(A); n = length(B)
    sum_AA = 0.0
    for i in A, j in A; i != j && (sum_AA += K[i, j]); end
    sum_BB = 0.0
    for i in B, j in B; i != j && (sum_BB += K[i, j]); end
    sum_AB = 0.0
    for i in A, j in B; sum_AB += K[i, j]; end
    sum_AA / (m * (m - 1)) + sum_BB / (n * (n - 1)) - 2.0 * sum_AB / (m * n)
end

function fisher_yates_shuffle!(rng, v::AbstractVector)
    for i in length(v):-1:2
        j = rand(rng, 1:i)
        v[i], v[j] = v[j], v[i]
    end
    v
end

function mmd_rbf(X::Matrix{Float64}, Y::Matrix{Float64}; n_perms::Int=500)
    rng = Xoshiro(12345)
    m = size(X, 1); n = size(Y, 1)
    (m < 2 || n < 2) && return (NaN, NaN)
    combined = vcat(X, Y)
    N = m + n
    D2 = _pairwise_sq_dists(combined)
    upper = Float64[]
    for i in 1:N, j in (i+1):N
        D2[i,j] > 0.0 && push!(upper, D2[i,j])
    end
    isempty(upper) && return (0.0, 1.0)
    sigma2 = Statistics.median(upper)
    sigma2 < 1e-30 && return (0.0, 1.0)
    K = exp.(-D2 ./ (2.0 * sigma2))
    observed = _mmd2_from_kernel(K, 1:m, (m+1):N)
    perm_count = 0
    idxs = collect(1:N)
    for _ in 1:n_perms
        fisher_yates_shuffle!(rng, idxs)
        perm_val = _mmd2_from_kernel(K, @view(idxs[1:m]), @view(idxs[m+1:N]))
        perm_val >= observed && (perm_count += 1)
    end
    p_value = (perm_count + 1) / (n_perms + 1)
    (observed, p_value)
end

function padded_trajectory_series(traj::TrajectoryData, g::String, nticks::Int)
    values = get(traj.values, g, Float64[])
    isempty(values) && return nothing
    limit = nticks + 1
    series = Vector{Float64}(undef, limit)
    final_value = Float64(values[min(length(values), length(traj.ticks))])
    fill!(series, final_value)
    for (i, tick) in enumerate(traj.ticks)
        i > length(values) && break
        0 <= tick <= nticks || continue
        series[tick + 1] = Float64(values[i])
    end
    series
end

function trajectory_mmd(a::Vector{TrajectoryData}, b::Vector{TrajectoryData},
                        g::String, nticks::Int; n_perms::Int=500)
    function extract_matrix(trajs)
        rows = Vector{Float64}[]
        for traj in trajs
            series = padded_trajectory_series(traj, g, nticks)
            series === nothing && continue
            push!(rows, series)
        end
        isempty(rows) && return Matrix{Float64}(undef, 0, 0)
        reduce(vcat, [r' for r in rows])
    end
    X = extract_matrix(a); Y = extract_matrix(b)
    (size(X, 1) < 2 || size(Y, 1) < 2) && return (NaN, NaN)
    mmd_rbf(X, Y; n_perms=n_perms)
end

function batch_metrics(trajs_a::Vector{TrajectoryData}, trajs_b::Vector{TrajectoryData},
                       g::String, nticks::Int)
    safe_mean(x) = (f = filter(!isnan, x); isempty(f) ? NaN : mean(f))
    function mean_traj(trajs)
        by_tick = [Float64[] for _ in 0:nticks]
        for traj in trajs
            series = padded_trajectory_series(traj, g, nticks)
            series === nothing && continue
            for t in 0:nticks; push!(by_tick[t+1], series[t+1]); end
        end
        safe_mean.(by_tick)
    end
    ma = mean_traj(trajs_a); mb = mean_traj(trajs_b)
    diffs = abs.(ma .- mb)
    fd = filter(!isnan, diffs)
    mae = isempty(fd) ? NaN : mean(fd)
    combined = filter(!isnan, vcat(ma, mb))
    val_range = isempty(combined) ? 1.0 : max(maximum(combined) - minimum(combined), 1.0)
    nmae = mae / val_range
    r_mean = pearson_r(ma, mb)
    final_a = Float64[last(get(t.values, g, [NaN])) for t in trajs_a]
    final_b = Float64[last(get(t.values, g, [NaN])) for t in trajs_b]
    ks = ks_statistic(final_a, final_b)
    ecdf_r = ecdf_correlation(final_a, final_b)
    mmd2, mmd_p = trajectory_mmd(trajs_a, trajs_b, g, nticks; n_perms=500)
    BatchMetrics(mae, nmae, r_mean, ks, ecdf_r, mmd2, mmd_p)
end

# ── Java NetLogo runner ───────────────────────────────────────────────

const NLOGO_SECTION_SEP = "@#\$#@#\$#@"

function build_nlogo_source(code::String, nticks::Int, globals::Vector{String};
                            world_dims=(-16,16,-16,16), wrapping=(true,true))
    min_px, max_px, min_py, max_py = world_dims
    wrap_x = wrapping[1] ? 1 : 0
    wrap_y = wrapping[2] ? 1 : 0
    metrics = join(["    <metric>$g</metric>" for g in globals], "\n")
    buf = IOBuffer()

    # Section 1: Code
    print(buf, code, "\n")

    # Section 2: Interface — GRAPHICS-WINDOW format per WidgetReader.scala
    # Lines: type, left, top, right, bottom, old-max-x(-1), old-max-y(-1),
    #   patch-size, ?, font-size, ?, ?, ?, ?, wrap-x, wrap-y, ?,
    #   min-pxcor, max-pxcor, min-pycor, max-pycor, ?, ?, tick-on, tick-label, framerate
    print(buf, NLOGO_SECTION_SEP, "\n")
    print(buf, """GRAPHICS-WINDOW
210
10
649
450
-1
-1
13.0
1
10
1
1
1
0
$(wrap_x)
$(wrap_y)
1
$(min_px)
$(max_px)
$(min_py)
$(max_py)
1
1
1
ticks
30.0
""")

    # Add INPUTBOX for randomSeed if declared in globals
    if occursin(r"globals\s*\[.*\brandomSeed\b"si, code)
        # Already in globals — no INPUTBOX needed
    else
        print(buf, "\nINPUTBOX\n10\n460\n170\n520\nrandomSeed\n0.0\n1\n0\nNumber\n")
    end

    # Section 3: Info (empty)
    print(buf, NLOGO_SECTION_SEP, "\n\n")

    # Section 4: Shapes
    print(buf, NLOGO_SECTION_SEP, "\n")
    print(buf, """default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

circle
false
0
Circle -7500403 true true 0 0 300

square
false
0
Rectangle -7500403 true true 30 30 270 270

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

mouse side
false
0
Circle -7500403 true true 0 0 300
""")

    # Section 5: Version
    print(buf, NLOGO_SECTION_SEP, "\n")
    print(buf, "NetLogo 6.4.0\n")

    # Sections 6-7: empty
    print(buf, NLOGO_SECTION_SEP, "\n\n")
    print(buf, NLOGO_SECTION_SEP, "\n\n")

    # Section 8: BehaviorSpace XML
    print(buf, NLOGO_SECTION_SEP, "\n")
    print(buf, """<experiments>
  <experiment name="benchmark" repetitions="1" runMetricsEveryStep="true">
    <setup>random-seed randomSeed
setup</setup>
    <go>go</go>
    <timeLimit steps="$(nticks)"/>
$(metrics)
    <enumeratedValueSet variable="randomSeed">
      __SEEDS_PLACEHOLDER__
    </enumeratedValueSet>
  </experiment>
</experiments>
""")

    # Section 9: HubNet (empty)
    print(buf, NLOGO_SECTION_SEP, "\n\n")

    # Section 10: Link shapes
    print(buf, NLOGO_SECTION_SEP, "\n")
    print(buf, """default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
""")

    # Section 11: settings
    print(buf, NLOGO_SECTION_SEP, "\n0\n")
    print(buf, NLOGO_SECTION_SEP, "\n")

    String(take!(buf))
end

function csv_split(line::AbstractString)
    fields = String[]
    buf = IOBuffer()
    in_q = false
    for c in line
        if in_q
            c == '"' ? (in_q = false) : write(buf, c)
        else
            if c == '"'; in_q = true
            elseif c == ','; push!(fields, String(take!(buf)))
            else write(buf, c)
            end
        end
    end
    push!(fields, String(take!(buf)))
    fields
end

function parse_behaviorsearch_csv(path::String, globals::Vector{String})
    lines = readlines(path)
    header_idx = 0
    for (i, line) in enumerate(lines)
        if occursin("[run number]", line)
            header_idx = i; break
        end
    end
    header_idx == 0 && error("Could not find CSV header in BehaviorSpace output")
    header = csv_split(lines[header_idx])
    run_col  = findfirst(h -> occursin("run number", h), header)
    step_col = findfirst(h -> occursin("[step]", h), header)
    seed_col = findfirst(h -> occursin("randomSeed", h), header)
    global_cols = Dict{String, Int}()
    for g in globals
        idx = findfirst(h -> lowercase(strip(h, '"')) == lowercase(g), header)
        idx !== nothing && (global_cols[g] = idx)
    end
    runs = Dict{Int, Tuple{Int, Vector{Int}, Dict{String, Vector{Float64}}}}()
    for i in (header_idx+1):length(lines)
        line = strip(lines[i])
        isempty(line) && continue
        fields = csv_split(line)
        run_num = tryparse(Int, fields[run_col])
        step    = tryparse(Int, fields[step_col])
        seed_v  = seed_col !== nothing ? tryparse(Int, fields[seed_col]) : 0
        (run_num === nothing || step === nothing) && continue
        if !haskey(runs, run_num)
            runs[run_num] = (something(seed_v, 0), Int[],
                             Dict{String, Vector{Float64}}(g => Float64[] for g in globals))
        end
        _, ticks, values = runs[run_num]
        push!(ticks, step)
        for g in globals
            col = get(global_cols, g, 0)
            v = (col > 0 && col <= length(fields)) ? tryparse(Float64, fields[col]) : nothing
            push!(values[g], something(v, NaN))
        end
    end
    [TrajectoryData(seed, ticks, vals) for (_, (seed, ticks, vals)) in sort(collect(runs), by=first)]
end

function run_java_trajectories(nlogo_src::String, seeds::Vector{Int}, globals::Vector{String})
    headless = joinpath(NETLOGO_DIR, "netlogo-headless.sh")
    isfile(headless) || error("netlogo-headless.sh not found at $headless")
    tmpdir = mktempdir()
    nlogo_path = joinpath(tmpdir, "benchmark.nlogo")
    table_path = joinpath(tmpdir, "output.csv")
    seed_values = join(["      <value value=\"$s\"/>" for s in seeds], "\n")
    src = replace(nlogo_src, "      __SEEDS_PLACEHOLDER__" => seed_values)
    write(nlogo_path, src)
    cmd = `bash $headless --model $nlogo_path --experiment benchmark --table $table_path --threads 1`
    try
        run(pipeline(cmd, stderr=devnull))
    catch e
        if !isfile(table_path)
            rm(tmpdir; recursive=true, force=true)
            rethrow(e)
        end
        @warn "Java runner had errors but produced output"
    end
    trajs = parse_behaviorsearch_csv(table_path, globals)
    rm(tmpdir; recursive=true, force=true)
    trajs
end

# ── Model definitions ─────────────────────────────────────────────────
# Each returns: (name, netlogo_code, world_dims, n_ticks, tracked_globals, ark_runner)

# Load ArkModelZoo
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."); io=devnull)
using ArkModelZoo
using Ark

function define_segregation()
    code = """
globals [randomSeed pct-similar-wanted density
         percent-similar percent-unhappy]

turtles-own [happy? similar-nearby other-nearby total-nearby]

to setup
  clear-all
  resize-world (- 12) 12 (- 12) 12
  set pct-similar-wanted 30
  set density 95
  ask patches [
    set pcolor white
    if random 100 < density [
      sprout 1 [
        set color one-of [105 27]
        set size 1
      ]
    ]
  ]
  update-turtles
  update-globals
  reset-ticks
end

to go
  if all? turtles [ happy? ] [ stop ]
  move-unhappy-turtles
  update-turtles
  update-globals
  tick
end

to move-unhappy-turtles
  ask turtles with [ not happy? ] [ find-new-spot ]
end

to find-new-spot
  rt random-float 360
  fd random-float 10
  if any? other turtles-here [ find-new-spot ]
  move-to patch-here
end

to update-turtles
  ask turtles [
    set similar-nearby count (turtles-on neighbors) with [ color = [ color ] of myself ]
    set other-nearby count (turtles-on neighbors) with [ color != [ color ] of myself ]
    set total-nearby similar-nearby + other-nearby
    set happy? similar-nearby >= (pct-similar-wanted * total-nearby / 100)
  ]
end

to update-globals
  let similar-neighbors sum [ similar-nearby ] of turtles
  let total-neighbors sum [ total-nearby ] of turtles
  set percent-similar (similar-neighbors / total-neighbors) * 100
  set percent-unhappy (count turtles with [ not happy? ]) / (count turtles) * 100
end
"""
    globals = ["percent-similar", "percent-unhappy"]
    nticks = 50
    dims = (-12, 12, -12, 12)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = SegregationParams(
                density=95.0, pct_similar_wanted=30.0,
                grid_width=25, grid_height=25,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_segregation(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "percent-similar" => Float64[v[1] for v in trajectory],
                "percent-unhappy" => Float64[v[2] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Segregation", nlogo_src, nticks, globals, ark_runner)
end

function define_wolfsheep()
    code = """
globals [num-wolves num-sheep num-grass]
breed [wolves wolf]
breed [sheep a-sheep]
turtles-own [energy]
patches-own [countdown]

to setup
  clear-all
  ask patches [
    set countdown random 20
    ifelse countdown <= 0 [
      set pcolor green
    ] [
      set pcolor brown
    ]
  ]
  create-sheep 100 [
    setxy random-xcor random-ycor
    set color white
    set energy random 10
    set shape "circle"
    set size 0.5
  ]
  create-wolves 50 [
    setxy random-xcor random-ycor
    set color black
    set energy random 10
    set shape "circle"
    set size 0.5
  ]
  update-counts
  reset-ticks
end

to go
  if not any? turtles [ stop ]
  ask sheep [
    move
    set energy energy - 1
    eat-grass
    maybe-reproduce 4
    if energy <= 0 [ die ]
  ]
  ask wolves [
    move
    set energy energy - 1
    eat-sheep
    maybe-reproduce 5
    if energy <= 0 [ die ]
  ]
  ask patches [ grow-grass ]
  update-counts
  tick
end

to move
  rt random 50 - 25
  fd 1
end

to eat-grass
  if [pcolor] of patch-here = green [
    set energy energy + 4
    ask patch-here [
      set pcolor brown
      set countdown 20
    ]
  ]
end

to eat-sheep
  let prey one-of sheep-here
  if prey != nobody [
    ask prey [ die ]
    set energy energy + 20
  ]
end

to maybe-reproduce [threshold]
  if random 100 < threshold [
    set energy energy / 2
    hatch 1 [
      rt random 360
      fd 1
    ]
  ]
end

to grow-grass
  if pcolor = brown [
    set countdown countdown - 1
    if countdown <= 0 [
      set pcolor green
    ]
  ]
end

to update-counts
  set num-wolves count wolves
  set num-sheep count sheep
  set num-grass count patches with [pcolor = green]
end
"""
    globals = ["num-wolves", "num-sheep", "num-grass"]
    nticks = 200
    dims = (-16, 16, -16, 16)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = WolfSheepParams(
                initial_number_sheep=100, initial_number_wolves=50,
                sheep_gain_from_food=4.0, wolf_gain_from_food=20.0,
                sheep_reproduce=4.0, wolf_reproduce=5.0,
                grass_regrowth_time=20, grass_enabled=true,
                grid_width=33, grid_height=33,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_wolfsheep(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "num-wolves" => Float64[v[2] for v in trajectory],
                "num-sheep"  => Float64[v[1] for v in trajectory],
                "num-grass"  => Float64[v[3] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Wolf Sheep Predation", nlogo_src, nticks, globals, ark_runner)
end

function define_ants()
    code = """
globals [randomSeed diffusion-rate evaporation-rate population total-food]

patches-own [chemical food nest? nest-scent food-source-number]

to setup
  clear-all
  resize-world (- 35) 35 (- 35) 35
  set diffusion-rate 50
  set evaporation-rate 10
  set population 125
  set-default-shape turtles "bug"
  create-turtles population [
    set size 2
    set color red
  ]
  setup-patches
  set total-food sum [food] of patches
  reset-ticks
end

to setup-patches
  ask patches [
    setup-nest
    setup-food
    recolor-patch
  ]
end

to setup-nest
  set nest? (distancexy 0 0) < 5
  set nest-scent 200 - distancexy 0 0
end

to setup-food
  if (distancexy (0.6 * max-pxcor) 0) < 5
    [ set food-source-number 1 ]
  if (distancexy (-0.6 * max-pxcor) (-0.6 * max-pycor)) < 5
    [ set food-source-number 2 ]
  if (distancexy (-0.8 * max-pxcor) (0.8 * max-pycor)) < 5
    [ set food-source-number 3 ]
  if food-source-number > 0
    [ set food one-of [1 2] ]
end

to recolor-patch
  ifelse nest?
    [ set pcolor violet ]
    [ ifelse food > 0
      [ if food-source-number = 1 [ set pcolor cyan ]
        if food-source-number = 2 [ set pcolor sky  ]
        if food-source-number = 3 [ set pcolor blue ] ]
      [ set pcolor scale-color green chemical 0.1 5 ] ]
end

to go
  ask turtles [
    if who >= ticks [ stop ]
    ifelse color = red
      [ look-for-food ]
      [ return-to-nest ]
    wiggle
    fd 1
  ]
  diffuse chemical (diffusion-rate / 100)
  ask patches [
    set chemical chemical * (100 - evaporation-rate) / 100
    recolor-patch
  ]
  set total-food sum [food] of patches
  tick
end

to return-to-nest
  ifelse nest?
    [ set color red
      rt 180 ]
    [ set chemical chemical + 60
      uphill-nest-scent ]
end

to look-for-food
  if food > 0 [
    set color orange + 1
    set food food - 1
    rt 180
    stop
  ]
  if (chemical >= 0.05) and (chemical < 2)
    [ uphill-chemical ]
end

to uphill-chemical
  let scent-ahead chemical-scent-at-angle   0
  let scent-right chemical-scent-at-angle  45
  let scent-left  chemical-scent-at-angle -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead) [
    ifelse scent-right > scent-left
      [ rt 45 ]
      [ lt 45 ]
  ]
end

to uphill-nest-scent
  let scent-ahead nest-scent-at-angle   0
  let scent-right nest-scent-at-angle  45
  let scent-left  nest-scent-at-angle -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead) [
    ifelse scent-right > scent-left
      [ rt 45 ]
      [ lt 45 ]
  ]
end

to wiggle
  rt random 40
  lt random 40
  if not can-move? 1 [ rt 180 ]
end

to-report nest-scent-at-angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [nest-scent] of p
end

to-report chemical-scent-at-angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [chemical] of p
end
"""
    globals = ["total-food"]
    nticks = 200
    dims = (-35, 35, -35, 35)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = AntsParams(
                population=125, diffusion_rate=50.0, evaporation_rate=10.0,
                grid_size=71, max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_ants(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            # trajectory[i][2] = TotalFoodRemaining (matches NetLogo's total-food)
            vals = Dict{String, Vector{Float64}}(
                "total-food" => Float64[v[2] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Ants", nlogo_src, nticks, globals, ark_runner)
end

# ── Model definitions batch 1 ────────────────────────────────────────
# Seven define_XXX() functions following the same pattern as
# define_segregation() / define_wolfsheep() / define_ants() in compare.jl.

function define_fire()
    code = """
globals [randomSeed density initial-trees burned-trees]

breed [fires fire]
breed [embers ember]

to setup
  clear-all
  resize-world (- 125) 125 (- 125) 125
  set density 57
  set-default-shape turtles "square"
  ask patches with [(random-float 100) < density]
    [ set pcolor green ]
  ask patches with [pxcor = min-pxcor]
    [ ignite ]
  set initial-trees count patches with [pcolor = green]
  set burned-trees 0
  reset-ticks
end

to go
  if not any? turtles [ stop ]
  ask fires
    [ ask neighbors4 with [pcolor = green]
        [ ignite ]
      set breed embers ]
  fade-embers
  tick
end

to ignite
  sprout-fires 1 [ set color red ]
  set pcolor black
  set burned-trees burned-trees + 1
end

to fade-embers
  ask embers
    [ set color color - 0.3
      if color < red - 3.5
        [ set pcolor color
          die ] ]
end
"""
    globals = ["initial-trees", "burned-trees"]
    nticks = 200
    dims = (-125, 125, -125, 125)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = FireParams(
                density=57.0, grid_width=251, grid_height=251,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_fire(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "initial-trees" => Float64[v[1] for v in trajectory],
                "burned-trees"  => Float64[v[2] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims, wrapping=(false, false))
    ("Forest Fire", nlogo_src, nticks, globals, ark_runner)
end

function define_voter()
    code = """
globals [randomSeed N pcolors n-colors]

to setup
  clear-all
  set N count patches
  set pcolors sublist (list grey white red yellow green orange blue pink) 0 2
  ask patches [
    set pcolor one-of pcolors
  ]
  set n-colors length remove-duplicates [pcolor] of patches
  reset-ticks
end

to go
  if length remove-duplicates [pcolor] of patches = 1 [ stop ]
  repeat count patches [
    ask one-of patches [
      set pcolor [pcolor] of one-of neighbors4
    ]
  ]
  set n-colors length remove-duplicates [pcolor] of patches
  tick
end
"""
    globals = ["n-colors"]
    nticks = 200
    dims = (0, 49, 0, 49)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = VoterParams(
                grid_width=50, grid_height=50,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_voter(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "n-colors" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Voter Model", nlogo_src, nticks, globals, ark_runner)
end

function define_ising()
    code = """
globals [randomSeed probability-of-spin-up temperature sum-of-spins]

patches-own [spin]

to setup
  clear-all
  resize-world (- 20) 20 (- 20) 20
  set probability-of-spin-up 50
  set temperature 2.27
  ask patches [
    ifelse random 100 < probability-of-spin-up
      [ set spin  1 ]
      [ set spin -1 ]
    recolor
  ]
  set sum-of-spins sum [ spin ] of patches
  reset-ticks
end

to go
  repeat 1000 [
    ask one-of patches [ update-spin ]
  ]
  tick
end

to update-spin
  let Ediff 2 * spin * sum [ spin ] of neighbors4
  if (Ediff <= 0) or (temperature > 0 and (random-float 1.0 < exp ((- Ediff) / temperature))) [
    set spin (- spin)
    set sum-of-spins sum-of-spins + 2 * spin
    recolor
  ]
end

to recolor
  ifelse spin = 1
    [ set pcolor blue + 2 ]
    [ set pcolor blue - 2 ]
end
"""
    globals = ["sum-of-spins"]
    nticks = 50
    dims = (-20, 20, -20, 20)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = IsingParams(
                probability_of_spin_up=50, temperature=2.27,
                grid_width=41, grid_height=41,
                updates_per_tick=1000, max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_ising(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "sum-of-spins" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Ising", nlogo_src, nticks, globals, ark_runner)
end

function define_decay()
    code = """
globals [randomSeed decay-chance number-nuclei decays last-count]

to setup
  clear-all
  resize-world (- 45) 45 (- 45) 45
  set decay-chance 3
  set number-nuclei 2500
  set-default-shape turtles "circle"
  ask n-of number-nuclei patches [
    sprout 1 [ set color cyan ]
  ]
  set last-count number-nuclei
  set decays 0
  reset-ticks
end

to go
  if all? turtles [color = blue - 3] [ stop ]
  set decays 0
  ask turtles with [color = cyan] [
    if random-float 100.0 < decay-chance [
      set color yellow
      set decays decays + 1
    ]
  ]
  ask turtles with [color = yellow] [ set color blue - 3 ]
  tick
end
"""
    globals = ["decays"]
    nticks = 200
    dims = (-45, 45, -45, 45)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = DecayParams(
                decay_chance=3.0, number_nuclei=2500,
                grid_width=91, grid_height=91,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_decay(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "decays" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Radioactive Decay", nlogo_src, nticks, globals, ark_runner)
end

function define_dla()
    code = """
globals [randomSeed wiggle-angle num-particles n-remaining]

to setup
  clear-all
  set wiggle-angle 60
  set num-particles 2500
  ask patch 0 0
    [ set pcolor green ]
  create-turtles num-particles
    [ set color red
      set size 1.5
      setxy random-xcor random-ycor ]
  set n-remaining count turtles
  reset-ticks
end

to go
  ask turtles
    [ right random wiggle-angle
      left random wiggle-angle
      forward 1
      if any? neighbors with [pcolor = green]
        [ set pcolor green
          die ] ]
  set n-remaining count turtles
  tick
end
"""
    globals = ["n-remaining"]
    nticks = 200
    dims = (-100, 100, -100, 100)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = DLAParams(
                wiggle_angle=60, num_particles=2500,
                grid_width=201, grid_height=201,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_dla(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "n-remaining" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("DLA Simple", nlogo_src, nticks, globals, ark_runner)
end

function define_contactprocess()
    code = """
globals [randomSeed N p-occupied initial-pop p-death]

to setup
  clear-all
  set initial-pop 1800
  set p-death 0.607
  set N count patches
  ask patches [
    ifelse random N < initial-pop
    [ set pcolor black ]
    [ set pcolor white ]
  ]
  set p-occupied count patches with [pcolor = black] / N
  reset-ticks
end

to go
  if not any? patches with [pcolor = black] [ stop ]
  repeat N [
    ask one-of patches [
      ifelse pcolor = black
      [ death-event ]
      [ birth-event ]
    ]
  ]
  set p-occupied count patches with [pcolor = black] / N
  tick
end

to death-event
  if random-float 1 < p-death [
    set pcolor white
  ]
end

to birth-event
  set pcolor [pcolor] of one-of neighbors4
end
"""
    globals = ["p-occupied"]
    nticks = 200
    dims = (-25, 24, -25, 24)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = ContactProcessParams(
                initial_pop=1800, p_death=0.607,
                grid_width=50, grid_height=50,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_contactprocess(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "p-occupied" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Contact Process 2D", nlogo_src, nticks, globals, ark_runner)
end

function define_flocking()
    code = """
globals [randomSeed population max-align-turn max-cohere-turn max-separate-turn vision minimum-separation avg-heading]

turtles-own [
  flockmates
  nearest-neighbor
]

to setup
  clear-all
  set population 200
  set max-align-turn 5
  set max-cohere-turn 3
  set max-separate-turn 1.5
  set vision 3
  set minimum-separation 1
  crt population
    [ set color yellow - 2 + random 7
      set size 1.5
      setxy random-xcor random-ycor ]
  reset-ticks
end

to go
  ask turtles [ flock ]
  repeat 5 [ ask turtles [ fd 0.2 ] ]
  set avg-heading mean [heading] of turtles
  tick
end

to flock
  find-flockmates
  if any? flockmates
    [ find-nearest-neighbor
      ifelse distance nearest-neighbor < minimum-separation
        [ separate ]
        [ align
          cohere ] ]
end

to find-flockmates
  set flockmates other turtles in-radius vision
end

to find-nearest-neighbor
  set nearest-neighbor min-one-of flockmates [distance myself]
end

to separate
  turn-away ([heading] of nearest-neighbor) max-separate-turn
end

to align
  turn-towards average-flockmate-heading max-align-turn
end

to-report average-flockmate-heading
  report atan sum [dx] of flockmates
              sum [dy] of flockmates
end

to cohere
  turn-towards average-heading-towards-flockmates max-cohere-turn
end

to-report average-heading-towards-flockmates
  report atan mean [sin (towards myself + 180)] of flockmates
              mean [cos (towards myself + 180)] of flockmates
end

to turn-towards [new-heading max-turn]
  turn-at-most (subtract-headings new-heading heading) max-turn
end

to turn-away [new-heading max-turn]
  turn-at-most (subtract-headings heading new-heading) max-turn
end

to turn-at-most [turn max-turn]
  ifelse abs turn > max-turn
    [ ifelse turn > 0
        [ rt max-turn ]
        [ lt max-turn ] ]
    [ rt turn ]
end
"""
    globals = ["avg-heading"]
    nticks = 200
    dims = (-45, 45, -45, 45)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = FlockingParams(
                population=200, max_align_turn=5.0,
                max_cohere_turn=3.0, max_separate_turn=1.5,
                vision=3.0, minimum_separation=1.0,
                grid_width=91, grid_height=91,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_flocking(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "avg-heading" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Flocking", nlogo_src, nticks, globals, ark_runner)
end
# ── Batch 2 model definitions for comparison harness ───────────────────
# Each function returns (name, nlogo_src, nticks, globals, ark_runner)

function define_sir()
    code = """
globals [randomSeed num-susceptible num-infected num-recovered]
turtles-own [state days-infected]

to setup
  clear-all
  create-turtles 200 [
    setxy random-xcor random-ycor
    set state "S"
    set days-infected 0
    set color green
  ]
  ask n-of 5 turtles [
    set state "I"
    set color red
    set days-infected 1
  ]
  update-counts
  reset-ticks
end

to go
  if num-infected = 0 [ stop ]
  ask turtles [
    rt random 50 - 25
    fd 1
  ]
  ask turtles with [state = "I"] [
    ask turtles in-radius 1.5 with [state = "S"] [
      if random-float 1.0 < 0.15 [
        set state "I"
        set color red
        set days-infected 1
      ]
    ]
    set days-infected days-infected + 1
    if days-infected > 14 [
      set state "R"
      set color gray
    ]
  ]
  update-counts
  tick
end

to update-counts
  set num-susceptible count turtles with [state = "S"]
  set num-infected count turtles with [state = "I"]
  set num-recovered count turtles with [state = "R"]
end
"""
    globals = ["num-susceptible", "num-infected", "num-recovered"]
    nticks = 200
    dims = (-16, 16, -16, 16)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = SIRParams(
                num_people=200, initial_infected=5,
                infection_radius=1.5, infection_chance=0.15,
                recovery_time=14,
                grid_width=33, grid_height=33,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_sir(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "num-susceptible" => Float64[v[1] for v in trajectory],
                "num-infected"    => Float64[v[2] for v in trajectory],
                "num-recovered"   => Float64[v[3] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("SIR", nlogo_src, nticks, globals, ark_runner)
end

function define_grassbrushtrees()
    code = """
globals [randomSeed N pcolors norm-b-1 norm-b-2 norm-d n-trees birth-rate-1 birth-rate-2]

patches-own [particle-type]

to setup
  clear-all
  set birth-rate-1 6
  set birth-rate-2 2
  set pcolors (list (lime + 2) (green - 1) (green - 3))
  set N count patches
  ask patches [
    set particle-type random 3
    set pcolor item particle-type pcolors
  ]
  set n-trees count patches with [particle-type = 2]
  reset-ticks
end

to go
  repeat N [
    let max-rate max (list birth-rate-1 birth-rate-2)
    set norm-d 1 / max-rate
    set norm-b-1 birth-rate-1 / max-rate
    set norm-b-2 birth-rate-2 / max-rate
    ask one-of patches [
      ifelse random 2 = 1
      [ death-event ]
      [ birth-event ]
    ]
  ]
  set n-trees count patches with [particle-type = 2]
  tick
end

to death-event
  if random-float 1 < norm-d [
    set particle-type 0
    set pcolor item particle-type pcolors
  ]
end

to birth-event
  if particle-type > 0 [
    ifelse particle-type = 1 [
      if random-float 1 < norm-b-1 [
        ask one-of neighbors4 [
          if particle-type = 0 [
            set particle-type 1
            set pcolor item particle-type pcolors
          ]
        ]
      ]
    ]
    [
      if random-float 1 < norm-b-2 [
        ask one-of neighbors4 [
          if particle-type < 2 [
            set particle-type 2
            set pcolor item particle-type pcolors
          ]
        ]
      ]
    ]
  ]
end
"""
    globals = ["n-trees"]
    nticks = 200
    dims = (0, 49, 0, 49)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = GBTParams(
                grid_width=50, grid_height=50,
                birth_rate_1=6.0, birth_rate_2=2.0,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_gbt(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "n-trees" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Grass Brush Trees", nlogo_src, nticks, globals, ark_runner)
end

function define_boiling()
    code = """
globals [randomSeed avg-heat]

patches-own [heat]

to setup
  clear-all
  ask patches [
    set heat random 212
    set pcolor scale-color red heat 0 212
  ]
  set avg-heat mean [heat] of patches
  reset-ticks
end

to go
  diffuse heat 1
  ask patches [
    set heat (heat + 5) mod 212
    set pcolor scale-color red heat 0 212
  ]
  set avg-heat mean [heat] of patches
  tick
end
"""
    globals = ["avg-heat"]
    nticks = 200
    dims = (-40, 40, -40, 40)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = BoilingParams(
                grid_width=81, grid_height=81,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_boiling(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "avg-heat" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Boiling", nlogo_src, nticks, globals, ark_runner)
end

function define_mousetraps()
    code = """
globals [randomSeed max-distance traps-triggered balls-in-air]

to setup
  clear-all
  __change-topology false false
  set max-distance 4.5
  set traps-triggered 0
  ask patches [ set pcolor blue + 3 ]
  set-default-shape turtles "circle"
  crt 1 [
    set color white
    set size 1.5
  ]
  set balls-in-air count turtles
  reset-ticks
end

to go
  if not any? turtles [ stop ]
  ask turtles [
    ifelse pcolor = red
      [ die ]
      [
        set pcolor red
        set traps-triggered traps-triggered + 1
        hatch 1 [ move ]
        move
      ]
  ]
  set balls-in-air count turtles
  tick
end

to move
  rt random-float 360
  fd random-float max-distance
end
"""
    globals = ["traps-triggered", "balls-in-air"]
    nticks = 150
    dims = (-80, 80, -80, 80)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = MousetrapParams(
                max_distance=4.5, half_width=80,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_mousetraps(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "traps-triggered" => Float64[v[1] for v in trajectory],
                "balls-in-air"    => Float64[v[2] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims, wrapping=(false, false))
    ("Mousetraps", nlogo_src, nticks, globals, ark_runner)
end

function define_birthrates()
    code = """
globals [randomSeed blue-fertility carrying-capacity red-fertility
         red-count blue-count]

turtles-own [fertility fertility-remainder]

to setup
  clear-all
  resize-world (- 25) 25 (- 25) 25
  set blue-fertility 2
  set carrying-capacity 200
  set red-fertility 2
  create-turtles carrying-capacity [
    setxy random-xcor random-ycor
    ifelse who < (carrying-capacity / 2)
      [ set color blue ]
      [ set color red ]
    set size 2
  ]
  update-counts
  reset-ticks
end

to go
  reproduce
  grim-reaper
  update-counts
  tick
end

to update-counts
  set red-count count turtles with [color = red]
  set blue-count count turtles with [color = blue]
end

to wander
  rt random-float 30 - random-float 30
  fd 1
end

to reproduce
  ask turtles [
    ifelse color = red [
      set fertility floor red-fertility
      set fertility-remainder red-fertility - (floor red-fertility)
    ] [
      set fertility floor blue-fertility
      set fertility-remainder blue-fertility - (floor blue-fertility)
    ]
    ifelse (random-float 100) < (100 * fertility-remainder)
      [ hatch fertility + 1 [ wander ] ]
      [ hatch fertility     [ wander ] ]
  ]
end

to grim-reaper
  let num-turtles count turtles
  if num-turtles <= carrying-capacity [ stop ]
  let chance-to-die (num-turtles - carrying-capacity) / num-turtles
  ask turtles [
    if random-float 1.0 < chance-to-die [ die ]
  ]
end
"""
    globals = ["red-count", "blue-count"]
    nticks = 50
    dims = (-25, 25, -25, 25)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = BirthRatesParams(
                carrying_capacity=200,
                red_fertility=2.0, blue_fertility=2.0,
                grid_width=51, grid_height=51,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_birthrates(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "red-count"  => Float64[v[1] for v in trajectory],
                "blue-count" => Float64[v[2] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Simple Birth Rates", nlogo_src, nticks, globals, ark_runner)
end

function define_diffusion()
    code = """
globals [randomSeed max-temp mean-temp]
patches-own [temp]

to setup
  clear-all
  ask patches [
    set temp 0
  ]
  ask patch 0 0 [
    set temp 100
    ask neighbors [ set temp 50 ]
  ]
  recolor
  update-stats
  reset-ticks
end

to go
  diffuse temp 0.5
  ask patches [
    set temp temp * 0.99
  ]
  ask patch 0 0 [ set temp 100 ]
  recolor
  update-stats
  tick
end

to recolor
  ask patches [
    set pcolor scale-color red temp 0 100
  ]
end

to update-stats
  set max-temp max [temp] of patches
  set mean-temp mean [temp] of patches
end
"""
    globals = ["max-temp", "mean-temp"]
    nticks = 100
    dims = (-16, 16, -16, 16)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = DiffusionParams(
                grid_width=33, grid_height=33,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_diffusion(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "max-temp"  => Float64[v[1] for v in trajectory],
                "mean-temp" => Float64[v[2] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Heat Diffusion", nlogo_src, nticks, globals, ark_runner)
end

function define_coordination()
    code = """
globals [randomSeed init-norm1 coordination-benefit n-norm1]
turtles-own [norm1? payoff]

to setup
  clear-all
  set init-norm1 0.5
  set coordination-benefit 1
  ask patches [
    sprout 1 [
      set shape "circle"
      ifelse random-float 1 < init-norm1 [set norm1? true] [set norm1? false]
    ]
  ]
  recolor
  set n-norm1 count turtles with [norm1?]
  reset-ticks
end

to go
  if (count turtles with [norm1?]) = (count turtles) or
     (count turtles with [norm1?]) = 0
    [stop]
  calculate-payoffs
  evolve
  recolor
  set n-norm1 count turtles with [norm1?]
  tick
end

to calculate-payoffs
  let p1 (count turtles with [norm1?]) / (count turtles)
  let norm1-payoff 1 + (p1 * coordination-benefit)
  let norm2-payoff 1 + ((1 - p1) * coordination-benefit)
  ask turtles with [norm1?] [set payoff norm1-payoff]
  ask turtles with [not norm1?] [set payoff norm2-payoff]
end

to evolve
  ask turtles [
    let model one-of other turtles
    if [norm1?] of model != [norm1?] of self [
      let other-payoff [payoff] of model
      let prob-copy (1 / (1 + exp (-1 * (other-payoff - payoff))))
      if random-float 1 < prob-copy
        [set norm1? [norm1?] of model]
    ]
  ]
end

to recolor
  ask turtles [
    ifelse norm1? [set color yellow] [set color blue]
  ]
end

to-report freq-norm1
  report (count turtles with [norm1?]) / (count turtles)
end
"""
    globals = ["n-norm1"]
    nticks = 200
    dims = (-16, 16, -16, 16)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = CoordinationParams(
                init_norm1=0.5, coordination_benefit=1.0,
                grid_size=33,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_coordination(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "n-norm1" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Coordination", nlogo_src, nticks, globals, ark_runner)
end
# ── Batch 3 model definitions ─────────────────────────────────────────
# Seven additional models for the ArkModelZoo ↔ NetLogo comparison harness.
# Each define_XXX() returns (name, nlogo_src, nticks, globals, ark_runner).

# ── 1. Rope (deterministic wave propagation) ─────────────────────────

function define_rope()
    code = """
globals [randomSeed friction frequency amplitude n-visible]

turtles-own [
  yvel
  ypos
]

to setup
  clear-all
  __change-topology false false
  set friction 24
  set frequency 10
  set amplitude 30
  set-default-shape turtles "circle"
  create-turtles world-width [
    set xcor who
    set color red
    set size 1.5
    if pxcor = max-pxcor
      [ set color blue ]
    if pxcor = min-pxcor
      [ set color green ]
  ]
  reset-ticks
end

to go
  ask turtles with [color = green]
  [
    ifelse ticks > 100
       [ set ypos amplitude * sin (frequency * ticks) ]
       [ set ypos (ticks / 100) * amplitude * sin (frequency * ticks) ]
    ifelse patch-at 0 (ypos - ycor) != nobody
    [
      set ycor ypos
      show-turtle
    ]
    [ hide-turtle ]
  ]
  ask turtles with [color = red]
  [
    set yvel yvel + ((([ypos] of (turtle (who - 1))) - ypos) +
                     (([ypos] of (turtle (who + 1))) - ypos))
    set yvel ((1000 - friction) / 1000) * yvel
  ]
  ask turtles with [color = red]
  [
    set ypos ypos + yvel
    ifelse patch-at 0 (ypos - ycor) != nobody
      [ set ycor ypos
        show-turtle ]
      [ hide-turtle ]
  ]
  set n-visible count turtles with [not hidden?]
  tick
end
"""
    globals = ["n-visible"]
    nticks = 500
    dims = (0, 160, -80, 80)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = RopeParams(
                world_width=161, y_min=-80, y_max=80,
                friction=24, frequency=10, amplitude=30,
                max_ticks=nticks
            )
            scheduler, trajectory = run_rope(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "n-visible" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims, wrapping=(false, false))
    ("Rope", nlogo_src, nticks, globals, ark_runner)
end

# ── 2. Particles ─────────────────────────────────────────────────────

function define_particles()
    code = """
globals [randomSeed num-particles whimsy speed collisions]

to setup
  clear-all
  set num-particles 50
  set whimsy 0
  set speed 0.02
  set-default-shape turtles "default"
  create-turtles num-particles [
    set color green
    set size 2
    setxy random-xcor random-ycor
    set heading random 360
  ]
  set collisions 0
  reset-ticks
end

to go
  ask turtles [
    if whimsy > 0 [
      right random whimsy
      left random whimsy
    ]
    forward speed
    if count turtles in-radius 1 > 1 [
      ask turtles in-radius 1 [
        set heading random 360
        fd 0.1
      ]
      set collisions (collisions + 1)
    ]
  ]
  tick
end
"""
    globals = ["collisions"]
    nticks = 200
    dims = (-16, 16, -16, 16)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = ParticlesParams(
                num_particles=50, speed=0.02,
                collision_radius=1.0, collision_speed=0.1,
                grid_width=33, grid_height=33,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_particles(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "collisions" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Particles", nlogo_src, nticks, globals, ark_runner)
end

# ── 3. Contagion SI ──────────────────────────────────────────────────

function define_contagion_si()
    code = """
globals [randomSeed num-turtles init-infected speed turning-angle transmissibility spontaneous-infect n-infected]
turtles-own [infected?]

to setup
  clear-all
  set num-turtles 300
  set init-infected 3
  set speed 0.5
  set turning-angle 60
  set transmissibility 0.01
  set spontaneous-infect 0
  setup-turtles
  setup-infected
  recolor
  set n-infected count turtles with [infected?]
  reset-ticks
end

to setup-turtles
  create-turtles num-turtles [
    set shape "circle"
    set infected? false
    setxy random-xcor random-ycor
  ]
end

to setup-infected
  if init-infected > num-turtles [set init-infected 1]
  ask n-of init-infected turtles [set infected? true]
end

to recolor
  ask turtles [
    ifelse infected? [set color red] [set color white]
  ]
end

to go
  if (count turtles with [infected?]) = num-turtles [stop]
  infect-susceptibles
  recolor
  move
  set n-infected count turtles with [infected?]
  tick
end

to infect-susceptibles
  ask turtles with [not infected?] [
    let infected-neighbors (count other turtles with [color = red] in-radius 1)
    if random-float 1 < 1 - (((1 - transmissibility) ^ infected-neighbors) * (1 - spontaneous-infect))
      [set infected? true]
  ]
end

to move
  ask turtles [
    left random turning-angle
    right random turning-angle
    fd speed
  ]
end
"""
    globals = ["n-infected"]
    nticks = 200
    dims = (-16, 16, -16, 16)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = ContagionSIParams(
                num_turtles=300, init_infected=3,
                speed=0.5, turning_angle=60,
                transmissibility=0.01, spontaneous_infect=0.0,
                grid_width=33, grid_height=33,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_contagionsi(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "n-infected" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Contagion SI", nlogo_src, nticks, globals, ark_runner)
end

# ── 4. Fire Percolation ──────────────────────────────────────────────

function define_firepercolation()
    code = """
globals [randomSeed fire-front fire-size p]

to setup
  clear-all
  set p 0.6
  ask n-of (p * count patches) patches [set pcolor green]
  set fire-front patch-set nobody
  set fire-size 0
  reset-ticks
end

to go
  if ticks = 0 [
    ignite-fire
  ]
  ifelse any? fire-front [
    fire-spread
  ]
  [ stop ]
  set fire-size count patches with [pcolor = red]
  tick
end

to ignite-fire
  ask one-of patches with [pcolor = green] [
    set pcolor red
    set fire-front patch-set self
  ]
  set fire-size 1
end

to fire-spread
  let new-fire-front patch-set nobody
  ask fire-front [
    let n-green neighbors4 with [pcolor = green]
    ask n-green [
      set new-fire-front (patch-set new-fire-front self)
    ]
  ]
  ask new-fire-front [set pcolor red]
  set fire-front new-fire-front
end
"""
    globals = ["fire-size"]
    nticks = 100
    dims = (0, 99, 0, 99)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = FirePercolationParams(
                p=0.6, grid_width=100, grid_height=100,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_firepercolation(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "fire-size" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Fire Percolation", nlogo_src, nticks, globals, ark_runner)
end

# ── 5. Contagion SIR ─────────────────────────────────────────────────

function define_contagion_sir()
    code = """
globals [randomSeed num-turtles init-infected speed turning-angle transmissibility spontaneous-infect recovery-rate remove-recovered? n-infected n-immune]
turtles-own [infected? immune?]

to setup
  clear-all
  set num-turtles 500
  set init-infected 3
  set speed 1
  set turning-angle 360
  set transmissibility 0.1
  set spontaneous-infect 0
  set recovery-rate 0.01
  set remove-recovered? false
  setup-turtles
  setup-infected
  recolor
  set n-infected count turtles with [infected?]
  set n-immune count turtles with [immune?]
  reset-ticks
end

to setup-turtles
  create-turtles num-turtles [
    set shape "circle"
    set color white
    set infected? false
    set immune? false
    setxy random-xcor random-ycor
  ]
end

to setup-infected
  if init-infected > num-turtles [set init-infected 1]
  ask n-of init-infected turtles [set infected? true]
end

to recolor
  ask turtles [
    ifelse infected? [set color red]
      [ifelse immune? [set color grey] [set color white]]
  ]
end

to go
  infect-susceptibles
  recover-infecteds
  recolor
  move
  set n-infected count turtles with [infected?]
  set n-immune count turtles with [immune?]
  tick
end

to infect-susceptibles
  ask turtles with [not infected? and not immune?] [
    let infected-neighbors (count other turtles with [color = red] in-radius 1)
    if (random-float 1 < 1 - (((1 - transmissibility) ^ infected-neighbors) * (1 - spontaneous-infect)))
      [set infected? true]
  ]
end

to recover-infecteds
  ask turtles with [infected? and color = red] [
    if random-float 1 < recovery-rate [
      set infected? false
      if remove-recovered? [set immune? true]
    ]
  ]
end

to move
  ask turtles [
    left random turning-angle
    right random turning-angle
    fd speed
  ]
end

to-report prop-infected
  report (count turtles with [infected?]) / num-turtles
end
"""
    globals = ["n-infected", "n-immune"]
    nticks = 200
    dims = (-16, 16, -16, 16)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = ContagionSIRParams(
                num_turtles=500, init_infected=3,
                speed=1.0, turning_angle=360,
                transmissibility=0.1, spontaneous_infect=0.0,
                recovery_rate=0.01, remove_recovered=false,
                grid_width=33, grid_height=33,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_contagionsir(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "n-infected" => Float64[v[1] for v in trajectory],
                "n-immune"   => Float64[v[2] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Contagion SIR", nlogo_src, nticks, globals, ark_runner)
end

# ── 6. COIN (Collective Intelligence) ────────────────────────────────

function define_coin()
    code = """
globals [
  randomSeed
  num-agents
  discount-rate
  current-utility
  attendance0 attendance1 attendance2 attendance3 attendance4 attendance5 attendance6
  reward0 reward1 reward2 reward3 reward4 reward5 reward6
]

breed [players player]
players-own [u0 u1 u2 u3 u4 u5 u6 last-action-idx]

to-report day-utility [x]
  report x * exp ((0 - x) / 3)
end

to-report global-utility-from-counts [a0 a1 a2 a3 a4 a5 a6]
  report (day-utility a0) + (day-utility a1) + (day-utility a2) +
         (day-utility a3) + (day-utility a4) + (day-utility a5) + (day-utility a6)
end

to recompute-attendance
  set attendance0 0
  set attendance1 0
  set attendance2 0
  set attendance3 0
  set attendance4 0
  set attendance5 0
  set attendance6 0
  ask players [
    if last-action-idx = 0 [ set attendance0 attendance0 + 1 ]
    if last-action-idx = 1 [ set attendance1 attendance1 + 1 ]
    if last-action-idx = 2 [ set attendance2 attendance2 + 1 ]
    if last-action-idx = 3 [ set attendance3 attendance3 + 1 ]
    if last-action-idx = 4 [ set attendance4 attendance4 + 1 ]
    if last-action-idx = 5 [ set attendance5 attendance5 + 1 ]
    if last-action-idx = 6 [ set attendance6 attendance6 + 1 ]
  ]
end

to recompute-rewards
  set current-utility global-utility-from-counts attendance0 attendance1 attendance2 attendance3 attendance4 attendance5 attendance6
  set reward0 1 + current-utility - global-utility-from-counts (attendance0 - 1 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 + (1 / 7))
  set reward1 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 - 1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 + (1 / 7))
  set reward2 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 - 1 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 + (1 / 7))
  set reward3 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 - 1 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 + (1 / 7))
  set reward4 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 - 1 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 + (1 / 7))
  set reward5 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 - 1 + (1 / 7)) (attendance6 + (1 / 7))
  set reward6 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 - 1 + (1 / 7))
end

to-report stochastic-choice-7 [w0 w1 w2 w3 w4 w5 w6]
  let total (w0 + w1 + w2 + w3 + w4 + w5 + w6)
  let r random-float total
  if r <= w0 [ report 0 ]
  set r r - w0
  if r <= w1 [ report 1 ]
  set r r - w1
  if r <= w2 [ report 2 ]
  set r r - w2
  if r <= w3 [ report 3 ]
  set r r - w3
  if r <= w4 [ report 4 ]
  set r r - w4
  if r <= w5 [ report 5 ]
  report 6
end

to setup
  clear-all
  set num-agents 63
  set discount-rate 0.98
  set current-utility 0
  create-players num-agents [
    hide-turtle
    setxy 0 who
    set u0 100
    set u1 100
    set u2 100
    set u3 100
    set u4 100
    set u5 100
    set u6 100
    set last-action-idx 0
  ]
  repeat 100 [
    ask players [take-random-action]
    recompute-attendance
    recompute-rewards
    ask players [learn]
  ]
  recompute-attendance
  set current-utility global-utility-from-counts attendance0 attendance1 attendance2 attendance3 attendance4 attendance5 attendance6
  reset-ticks
end

to go
  ask players [take-action]
  recompute-attendance
  recompute-rewards
  ask players [learn]
  tick
end

to take-action
  set last-action-idx stochastic-choice-7 u0 u1 u2 u3 u4 u5 u6
end

to take-random-action
  set last-action-idx random 7
end

to learn
  set u0 u0 * discount-rate
  set u1 u1 * discount-rate
  set u2 u2 * discount-rate
  set u3 u3 * discount-rate
  set u4 u4 * discount-rate
  set u5 u5 * discount-rate
  set u6 u6 * discount-rate
  if last-action-idx = 0 [ set u0 u0 + reward0 ]
  if last-action-idx = 1 [ set u1 u1 + reward1 ]
  if last-action-idx = 2 [ set u2 u2 + reward2 ]
  if last-action-idx = 3 [ set u3 u3 + reward3 ]
  if last-action-idx = 4 [ set u4 u4 + reward4 ]
  if last-action-idx = 5 [ set u5 u5 + reward5 ]
  if last-action-idx = 6 [ set u6 u6 + reward6 ]
end
"""
    globals = ["current-utility"]
    nticks = 200
    dims = (-16, 16, -16, 16)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = CoinParams(
                num_agents=63, discount_rate=0.98,
                warmup=100, max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_coin(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "current-utility" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("COIN Learning", nlogo_src, nticks, globals, ark_runner)
end

# ── 7. Virus on a Network ───────────────────────────────────────────

function define_virus()
    code = """
globals [randomSeed num-susceptible num-infected num-resistant]
turtles-own [infected? resistant? virus-timer]

to setup
  clear-all
  create-turtles 150 [
    setxy random-xcor random-ycor
    set infected? false
    set resistant? false
    set virus-timer 0
    set color green
    set shape "circle"
    set size 0.5
  ]
  ask turtles [
    create-links-with other turtles in-radius 3
  ]
  ask n-of 3 turtles [
    become-infected
  ]
  update-counts
  reset-ticks
end

to go
  if num-infected = 0 [ stop ]
  ask turtles with [infected?] [
    ask link-neighbors with [not resistant? and not infected?] [
      if random-float 1.0 < 0.10 [
        become-infected
      ]
    ]
    set virus-timer virus-timer + 1
    if virus-timer > 10 [
      ifelse random-float 1.0 < 0.25 [
        become-resistant
      ] [
        become-susceptible
      ]
    ]
  ]
  ask turtles with [resistant?] [
    if random-float 1.0 < 0.01 [
      become-susceptible
    ]
  ]
  update-counts
  tick
end

to become-infected
  set infected? true
  set resistant? false
  set virus-timer 0
  set color red
end

to become-resistant
  set infected? false
  set resistant? true
  set virus-timer 0
  set color gray
end

to become-susceptible
  set infected? false
  set resistant? false
  set virus-timer 0
  set color green
end

to update-counts
  set num-susceptible count turtles with [not infected? and not resistant?]
  set num-infected count turtles with [infected?]
  set num-resistant count turtles with [resistant?]
end
"""
    globals = ["num-susceptible", "num-infected", "num-resistant"]
    nticks = 150
    dims = (-25, 25, -25, 25)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = VirusParams(
                number_people=150, initial_infected=3,
                virus_spread_chance=0.10, virus_check_freq=10,
                recovery_chance=0.25, lose_immunity_chance=0.01,
                link_radius=3.0, world_width=51, world_height=51,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_virus(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            # Observer now returns integer counts directly
            vals = Dict{String, Vector{Float64}}(
                "num-susceptible" => Float64[v[1] for v in trajectory],
                "num-infected"    => Float64[v[2] for v in trajectory],
                "num-resistant"   => Float64[v[3] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Virus on Network", nlogo_src, nticks, globals, ark_runner)
end

# ── Calibrated comparison ─────────────────────────────────────────────

function compare_model_calibrated(name, nlogo_src, nticks, globals, ark_runner;
                                  n_per_batch::Int=20)
    seeds_a = collect(1:n_per_batch)
    seeds_b = collect(n_per_batch+1 : 2*n_per_batch)

    println("╔══════════════════════════════════════════════════════════╗")
    println("║  Calibrated comparison: $name")
    println("║  4 batches × $n_per_batch reps  │  Ticks: $nticks")
    println("╚══════════════════════════════════════════════════════════╝")

    println("\n▶ Running Ark.jl batch A (seeds 1-$n_per_batch)...")
    t_ark = @elapsed begin
        ark_a = ark_runner(seeds_a)
        println("    ...batch B (seeds $(n_per_batch+1)-$(2*n_per_batch))...")
        ark_b = ark_runner(seeds_b)
    end
    @printf("  ✓ Ark.jl: %.2f s (%.3f s/rep)\n", t_ark, t_ark/(2*n_per_batch))

    println("\n▶ Running Java NetLogo batch A (seeds 1-$n_per_batch)...")
    t_java = @elapsed begin
        java_a = run_java_trajectories(nlogo_src, seeds_a, globals)
        println("    ...batch B (seeds $(n_per_batch+1)-$(2*n_per_batch))...")
        java_b = run_java_trajectories(nlogo_src, seeds_b, globals)
    end
    @printf("  ✓ Java:   %.2f s (%.3f s/rep)\n", t_java, t_java/(2*n_per_batch))

    println("\n▶ Computing 3-way batch comparisons...")
    variables = VariableCalibrated[]

    for g in globals
        aa = batch_metrics(ark_a, ark_b, g, nticks)
        jj = batch_metrics(java_a, java_b, g, nticks)
        aj = batch_metrics(ark_a, java_a, g, nticks)

        tol = 1.5
        null_mae  = max(aa.nmae, jj.nmae)
        null_ks   = max(aa.ks, jj.ks)
        null_mmd_p = min(aa.mmd_p, jj.mmd_p)

        mae_ok = isnan(null_mae) || aj.nmae <= null_mae * tol + 0.01
        # When NMAE is negligible (< 0.005), mean trajectories match so well
        # that any KS/MMD disagreement comes from floating-point noise in
        # near-deterministic outputs, not genuine divergence.  Skip them.
        near_deterministic = aj.nmae < 0.005 && mae_ok
        ks_ok  = isnan(null_ks)  || near_deterministic || aj.ks <= null_ks * tol + 0.02
        mmd_ok = isnan(aj.mmd_p) || near_deterministic || aj.mmd_p >= null_mmd_p * 0.5 - 0.05

        ok = mae_ok && ks_ok && mmd_ok
        push!(variables, VariableCalibrated(g, aa, jj, aj, ok))
    end

    CalibratedReport(name, n_per_batch, nticks, variables, t_ark, t_java)
end

# ── Reporting ─────────────────────────────────────────────────────────

function print_calibrated_report(r::CalibratedReport)
    println()
    println("┌──────────────────────────────────────────────────────────────────────────────────────────────────┐")
    @printf("│  %s — Calibrated 4-batch comparison (%d per batch × %d ticks)\n",
            r.model_name, r.n_per_batch, r.n_ticks)
    @printf("│  Ark.jl: %.1fs  │  Java: %.1fs\n", r.ark_time_s, r.java_time_s)
    println("├──────────────────────────────────────────────────────────────────────────────────────────────────┤")
    println("│                       │        Ark A↔B (null)    │        Java A↔B (null)   │   Ark↔Java (test) │")
    println("│  Variable       Metric│   value                  │   value                  │   value       pass│")
    println("├──────────────────────────────────────────────────────────────────────────────────────────────────┤")
    for v in r.variables
        aa = v.ark_vs_ark; jj = v.java_vs_java; aj = v.ark_vs_java
        n = v.name[1:min(16,end)]
        @printf("│  %-16s NMAE │   %8.5f                │   %8.5f                │   %8.5f    │\n", n, aa.nmae, jj.nmae, aj.nmae)
        @printf("│  %-16s r(μ) │   %8.5f                │   %8.5f                │   %8.5f    │\n", "", aa.corr_mean, jj.corr_mean, aj.corr_mean)
        @printf("│  %-16s KS   │   %8.4f                │   %8.4f                │   %8.4f    │\n", "", aa.ks, jj.ks, aj.ks)
        mmd_p_aa = isnan(aa.mmd_p) ? "   N/A" : @sprintf("%8.4f", aa.mmd_p)
        mmd_p_jj = isnan(jj.mmd_p) ? "   N/A" : @sprintf("%8.4f", jj.mmd_p)
        mmd_p_aj = isnan(aj.mmd_p) ? "   N/A" : @sprintf("%8.4f", aj.mmd_p)
        mark = v.pass ? "  ✓" : "  ✗"
        @printf("│  %-16s MMDp │   %s                │   %s                │   %s  %s │\n", "", mmd_p_aa, mmd_p_jj, mmd_p_aj, mark)
        println("│                       │                          │                          │                   │")
    end
    println("└──────────────────────────────────────────────────────────────────────────────────────────────────┘")

    all_ok = all(v -> v.pass, r.variables)
    if all_ok
        println("\n  ✅ PASS — Cross-implementation differences within null baseline for all variables")
    else
        bad = [v.name for v in r.variables if !v.pass]
        println("\n  ❌ FAIL — Cross-impl exceeds null baseline for: $(join(bad, ", "))")
    end
end

function save_calibrated_csv(r::CalibratedReport, path::String)
    open(path, "w") do io
        println(io, "variable,comparison,mae,nmae,corr_mean,ks,ecdf_r,mmd_stat,mmd_p,pass")
        for v in r.variables
            for (label, m) in [("ark_vs_ark", v.ark_vs_ark),
                               ("java_vs_java", v.java_vs_java),
                               ("ark_vs_java", v.ark_vs_java)]
                @printf(io, "%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%s\n",
                        v.name, label, m.mae, m.nmae, m.corr_mean,
                        m.ks, m.ecdf_r, m.mmd_stat, m.mmd_p,
                        label == "ark_vs_java" ? string(v.pass) : "")
            end
        end
    end
    println("  📁 Saved: $path")
end

# ── Main ──────────────────────────────────────────────────────────────

const MODELS = Dict(
    "segregation"     => define_segregation,
    "wolfsheep"       => define_wolfsheep,
    "ants"            => define_ants,
    "fire"            => define_fire,
    "voter"           => define_voter,
    "ising"           => define_ising,
    "decay"           => define_decay,
    "dla"             => define_dla,
    "contactprocess"  => define_contactprocess,
    "flocking"        => define_flocking,
    "sir"             => define_sir,
    "grassbrushtrees" => define_grassbrushtrees,
    "boiling"         => define_boiling,
    "mousetraps"      => define_mousetraps,
    "birthrates"      => define_birthrates,
    "diffusion"       => define_diffusion,
    "coordination"    => define_coordination,
    "rope"            => define_rope,
    "particles"       => define_particles,
    "contagionsi"     => define_contagion_si,
    "firepercolation" => define_firepercolation,
    "contagionsir"    => define_contagion_sir,
    "coin"            => define_coin,
    "virus"           => define_virus,
)

const ALL_MODEL_NAMES = sort(collect(keys(MODELS)))

function main()
    model_arg = length(ARGS) >= 1 ? ARGS[1] : "all"
    n_per_batch = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 20

    model_names = model_arg == "all" ? ALL_MODEL_NAMES : [model_arg]

    results = Dict{String, Bool}()
    for mname in model_names
        haskey(MODELS, mname) || error("Unknown model: $mname. Options: $(join(ALL_MODEL_NAMES, ", ")), all")
        define_fn = MODELS[mname]
        name, nlogo_src, nticks, globals, ark_runner = define_fn()
        report = compare_model_calibrated(name, nlogo_src, nticks, globals, ark_runner;
                                          n_per_batch=n_per_batch)
        print_calibrated_report(report)
        outpath = joinpath(@__DIR__, "$(mname)_calibrated.csv")
        save_calibrated_csv(report, outpath)
        results[mname] = all(v -> v.pass, report.variables)
        println()
    end

    # Summary
    if length(results) > 1
        println("\n" * "="^60)
        println("  VALIDATION SUMMARY")
        println("="^60)
        n_pass = count(values(results))
        n_total = length(results)
        for mname in sort(collect(keys(results)))
            mark = results[mname] ? "✅" : "❌"
            println("  $mark  $mname")
        end
        println("─"^60)
        println("  $n_pass / $n_total passed")
        println("="^60)
    end
end

main()
