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
#
# Set NETLOGO_DIR to a NetLogo distribution containing netlogo-headless.sh
# if it is not discoverable from the local checkout layout.

using Printf
using Statistics
using Random

# ── Configuration ─────────────────────────────────────────────────────

const REPO_ROOT = normpath(joinpath(@__DIR__, ".."))

function _find_netlogo_dir()
    env_path = get(ENV, "NETLOGO_DIR", "")
    candidates = filter(!isempty, [
        env_path,
        normpath(joinpath(REPO_ROOT, "..", "..", "netlogo", "NetLogo-dist", "NetLogo-6.4.0-64")),
        normpath(joinpath(REPO_ROOT, "..", "NetLogo-dist", "NetLogo-6.4.0-64")),
    ])
    for candidate in candidates
        isdir(candidate) && return candidate
    end
    return nothing
end

const NETLOGO_DIR = _find_netlogo_dir()

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
                            world_dims=(-16,16,-16,16))
    min_px, max_px, min_py, max_py = world_dims
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
1
1
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
    NETLOGO_DIR === nothing &&
        error("NetLogo not found. Set NETLOGO_DIR to a NetLogo distribution containing netlogo-headless.sh.")
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
Pkg.activate(REPO_ROOT; io=devnull)
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
        ks_ok  = isnan(null_ks)  || aj.ks   <= null_ks  * tol + 0.02
        mmd_ok = isnan(aj.mmd_p) || aj.mmd_p >= null_mmd_p * 0.5 - 0.05

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
    "segregation" => define_segregation,
    "wolfsheep"   => define_wolfsheep,
    "ants"        => define_ants,
)

function main()
    model_arg = length(ARGS) >= 1 ? ARGS[1] : "all"
    n_per_batch = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 20

    model_names = model_arg == "all" ? ["segregation", "wolfsheep", "ants"] : [model_arg]

    for mname in model_names
        haskey(MODELS, mname) || error("Unknown model: $mname. Options: $(join(keys(MODELS), ", ")), all")
        define_fn = MODELS[mname]
        name, nlogo_src, nticks, globals, ark_runner = define_fn()
        report = compare_model_calibrated(name, nlogo_src, nticks, globals, ark_runner;
                                          n_per_batch=n_per_batch)
        print_calibrated_report(report)
        outpath = joinpath(@__DIR__, "$(mname)_calibrated.csv")
        save_calibrated_csv(report, outpath)
        println()
    end
end

main()
