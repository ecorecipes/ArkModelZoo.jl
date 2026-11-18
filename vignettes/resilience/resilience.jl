# Computations and figures for the resilience vignette (resilience.qmd).
# Run from the ArkModelZoo.jl root, ideally with a few threads:
#   julia -t 4 --project=vignettes vignettes/resilience/resilience.jl
# It writes the figures and results.toml next to this file.

using ArkModelZoo, Plots, Statistics, Random, TOML
using LinearAlgebra: BLAS
BLAS.set_num_threads(1)
gr()

const OUT = @__DIR__
results = Dict{String,Any}()

# ---------------------------------------------------------------- 1. Daisyworld basin stability

lums = 0.4:0.1:2.1
covers0 = (u, rng) -> [NaN, 0.5rand(rng), 0.5rand(rng)]      # random initial white and black cover
alive = u -> u[2] + u[3] > 0.05                               # daisies still there at the end
basin = map(lums) do L
    prob = DaisyworldProblem(DaisyworldParams(solar_luminosity = L, seed = 1); u0 = [NaN, 0.2, 0.2],
                             tspan = (0, 300))
    basin_stability(prob, TickStepping(); sample_perturbation = covers0, returned = alive,
                    trajectories = 100, ensemble = EnsembleThreads(), seed = 1)
end
results["daisyworld_basin"] = Dict("luminosity" => collect(lums), "fraction" => [b.fraction for b in basin],
                                   "se" => [b.se for b in basin])
plt = plot(collect(lums), [b.fraction for b in basin]; yerror = [b.se for b in basin], marker = :circle,
           xlabel = "solar luminosity", ylabel = "basin stability (fraction alive at tick 300)",
           legend = false, ylims = (-0.02, 1.02), size = (700, 400))
savefig(plt, joinpath(OUT, "fig_basin.png"))

# ---------------------------------------------------------------- 2. early warnings before the hot collapse

ramp_rate = 0.0005                                            # luminosity per tick, from 1.0
ramp = (p, t) -> (q = deepcopy(p); q.solar_luminosity = 1.0 + ramp_rate * t; q)
tick_times = 0:2:2400
function series(seed; ramped)
    prob = DaisyworldProblem(DaisyworldParams(solar_luminosity = 1.0, seed = seed); tspan = (0, last(tick_times)))
    s = ramped_series(prob, TickStepping(); saveat = tick_times, ramp = ramped ? ramp : nothing, observe = copy)
    return collect(s.t), reduce(hcat, s.x)'                   # rows are times; columns T, w, b
end

seeds = 1:10
burnin = 500                                                  # the start-up transient would dominate the trend
ews = Dict(:ramped => [], :constant => [])
example = nothing
for s in seeds
    t, X = series(s; ramped = true)
    collapse = findfirst(k -> X[k, 2] + X[k, 3] < 0.05, axes(X, 1))
    start = findfirst(≥(burnin), t)
    stop = collapse === nothing ? length(t) : collapse - 50  # 100 ticks before the collapse
    tc = collapse === nothing ? NaN : t[collapse]
    for (name, col) in (("temperature", 1), ("white", 2))
        e = early_warning(X[start:stop, col]; t = t[start:stop], window = 0.5)
        push!(ews[:ramped], (seed = s, var = name, tau_variance = e.tau_variance, tau_ac1 = e.tau_ac1,
                             collapse = tc, luminosity = 1.0 + ramp_rate * tc))
        s == 1 && name == "temperature" &&
            (global example = (t = t, X = X, start = start, stop = stop, e = e, tc = tc))
    end
    tn, Xn = series(s; ramped = false)
    for (name, col) in (("temperature", 1), ("white", 2))
        e = early_warning(Xn[start:stop, col]; t = tn[start:stop], window = 0.5)
        push!(ews[:constant], (seed = s, var = name, tau_variance = e.tau_variance, tau_ac1 = e.tau_ac1,
                               collapse = NaN, luminosity = 1.0))
    end
end
taus(kind, var, f) = [getfield(r, f) for r in ews[kind] if r.var == var]
results["daisyworld_ews"] = Dict(
    "ramp_rate" => ramp_rate, "burnin" => burnin,
    "collapse_tick" => [r.collapse for r in ews[:ramped] if r.var == "temperature"],
    "collapse_luminosity" => [r.luminosity for r in ews[:ramped] if r.var == "temperature"],
    (string(k, "_", v, "_", f) => taus(k, v, f) for k in (:ramped, :constant), v in ("temperature", "white"),
     f in (:tau_variance, :tau_ac1))...)

p1 = plot(example.t, example.X[:, 1]; label = "mean temperature", xlabel = "tick", ylabel = "°C")
vline!(p1, [example.t[example.start], example.t[example.stop]]; label = "analysed window", ls = :dash)
isnan(example.tc) || vline!(p1, [example.tc]; label = "daisies gone", ls = :dot)
p2 = plot(example.e.t, example.e.variance; xlabel = "tick", ylabel = "rolling variance", legend = false)
p3 = plot(example.e.t, example.e.ac1; xlabel = "tick", ylabel = "rolling lag-1 autocorrelation", legend = false)
labels = ["ramped\nvariance" "constant\nvariance" "ramped\nAC1" "constant\nAC1"]
p4 = scatter([fill(1, 10) fill(2, 10) fill(3, 10) fill(4, 10)],
             [taus(:ramped, "temperature", :tau_variance) taus(:constant, "temperature", :tau_variance) taus(:ramped, "temperature", :tau_ac1) taus(:constant, "temperature", :tau_ac1)];
             xticks = (1:4, vec(labels)), ylabel = "Kendall τ (temperature)", legend = false, ylims = (-1, 1))
hline!(p4, [0]; color = :gray, ls = :dash)
savefig(plot(p1, p2, p3, p4; layout = (2, 2), size = (1000, 700)), joinpath(OUT, "fig_ews.png"))

# ---------------------------------------------------------------- 3. Wolf–Sheep recovery after halving the sheep

halve_sheep = (u, rng) -> [u[1] / 2, u[2], u[3]]
same = (u, rng) -> u
animals = u -> u[1:2]
recoveries = []
for s in seeds
    prob = WolfSheepProblem(WolfSheepParams(seed = s); tspan = (0, 900))
    paired = recovery(prob, TickStepping(); perturb = halve_sheep, observe = animals, t_pulse = 300,
                      horizon = 600, interval = 5)
    # the noise floor: two runs with different seeds and no pulse
    noise = recovery(prob, TickStepping(); perturb = same, observe = animals, t_pulse = 300, horizon = 600,
                     interval = 5, seed = s, perturbed_seed = s + 10_000)
    level = median(noise.distance)
    back = findfirst(d -> d ≤ level, paired.distance)
    # `recovery` measures time from the pulse
    push!(recoveries, (seed = s, t = paired.t, paired = paired.distance, floor = noise.distance, level = level,
                       return_time = back === nothing ? Inf : paired.t[back]))
end
results["wolfsheep_recovery"] = Dict("return_time" => [r.return_time for r in recoveries],
                                     "noise_floor" => [r.level for r in recoveries],
                                     "initial_distance" => [r.paired[1] for r in recoveries])
tt = recoveries[1].t
med(f) = [median(getfield(r, f)[k] for r in recoveries) for k in eachindex(tt)]
p5 = plot(xlabel = "ticks after the pulse", ylabel = "distance (sheep, wolves)", size = (800, 450))
for r in recoveries
    plot!(p5, tt, r.paired; color = :steelblue, alpha = 0.25, label = false)
end
plot!(p5, tt, med(:paired); color = :steelblue, lw = 3, label = "paired: control vs pulsed (median)")
plot!(p5, tt, med(:floor); color = :orange, lw = 3, label = "independent runs, no pulse (median)")
savefig(p5, joinpath(OUT, "fig_recovery.png"))

# ---------------------------------------------------------------- 4. Wolf–Sheep coexistence basin

animals0 = (u, rng) -> [rand(rng, 0:300), rand(rng, 0:150), NaN]
both = u -> u[1] > 0 && u[2] > 0
coexist = Dict{String,Any}()
for grass in (true, false)
    prob = WolfSheepProblem(WolfSheepParams(seed = 1, grass_enabled = grass); u0 = [100, 50, NaN], tspan = (0, 1000))
    b = basin_stability(prob, TickStepping(); sample_perturbation = animals0, returned = both, trajectories = 100,
                        ensemble = EnsembleThreads(), seed = 2)
    coexist[grass ? "grass" : "no_grass"] = Dict("fraction" => b.fraction, "se" => b.se)
end
results["wolfsheep_coexistence"] = coexist

open(joinpath(OUT, "results.toml"), "w") do io
    TOML.print(io, results; sorted = true)
end
println("done: ", join(sort!(collect(keys(results))), ", "))
