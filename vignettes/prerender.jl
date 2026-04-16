# Pre-render all vignette plots in a single Julia session.
# Run from ArkModelZoo.jl root:
#   julia --project=vignettes -e 'using Pkg; Pkg.instantiate()'
#   julia --project=vignettes vignettes/prerender.jl
#
# Produces PNG files in each vignette directory:
#   vignettes/{model}/plot_timeseries.png
#   vignettes/{model}/plot_ensemble.png
#   vignettes/{model}/plot_sensitivity.png (if applicable)

import Pkg
Pkg.activate(@__DIR__; io=devnull)

using ArkModelZoo, Plots, Statistics
println("Packages loaded. Starting pre-render...")

# Discover all models by scanning src/
srcdir  = joinpath(@__DIR__, "..", "src")
vigdir  = joinpath(@__DIR__)
models  = String[]
for d in readdir(srcdir)
    dp = joinpath(srcdir, d)
    isdir(dp) || continue
    d in ("common", "ext") && continue
    isfile(joinpath(dp, "model.jl")) || continue
    push!(models, d)
end
sort!(models)

# Build lookup of (run_fn, params_struct, headers, sensitivity_param) per model
function parse_model_meta(name)
    mfile = joinpath(srcdir, name, "model.jl")
    mc = read(mfile, String)

    # run function name
    m_run = match(r"function (run_\w+)\(", mc)
    run_fn = m_run === nothing ? "run_$(name)" : m_run.captures[1]

    # headers from return [...] in observer
    m_hdr = match(r"return\s*\[([^\]]+)\]", mc)
    headers = String[]
    if m_hdr !== nothing
        for h in split(m_hdr.captures[1], ",")
            h = strip(h)
            h = strip(h, '"')
            push!(headers, h)
        end
    end

    # params struct name
    struct_name = nothing
    for fname in ("parameters.jl", "resources.jl")
        pfile = joinpath(srcdir, name, fname)
        isfile(pfile) || continue
        pc = read(pfile, String)
        m_st = match(r"struct\s+(\w*Params\w*)", pc)
        if m_st !== nothing
            struct_name = m_st.captures[1]
            # Find first interesting numeric param for sensitivity
            block = match(Regex("struct\\s+" * struct_name * "(.+?)end", "s"), pc)
            if block !== nothing
                skip = Set(["seed", "max_ticks", "grid_width", "grid_height",
                            "grid_size", "world_width", "world_height", "num_ticks"])
                for line in split(block.captures[1], "\n")
                    pm = match(r"^\s+(\w+)::(Int|Float64)\s*=\s*(.+?)(?:\s*#.*)?$", line)
                    if pm !== nothing && !(pm.captures[1] in skip)
                        return (run_fn, struct_name, headers, pm.captures[1], pm.captures[2], strip(pm.captures[3]))
                    end
                end
            end
            break
        end
    end
    return (run_fn, struct_name, headers, nothing, nothing, nothing)
end

total = length(models)
global succeeded = 0
global failed = String[]

for (i, name) in enumerate(models)
    print("[$i/$total] $name ... ")
    outdir = joinpath(vigdir, name)
    isdir(outdir) || mkpath(outdir)

    try
        run_fn_name, struct_name, headers, sens_param, sens_type, sens_default = parse_model_meta(name)

        # Get the actual functions/types from ArkModelZoo
        run_fn = getfield(ArkModelZoo, Symbol(run_fn_name))
        ParamsType = struct_name === nothing ? nothing : getfield(ArkModelZoo, Symbol(struct_name))

        # ── Plot 1: Time series ──
        _, trajectory = run_fn()
        data = reduce(hcat, trajectory)'
        ticks = 0:size(data, 1)-1
        n_cols = size(data, 2)
        hdrs = isempty(headers) ? ["var$i" for i in 1:n_cols] : headers

        if n_cols <= 4
            p1 = plot(ticks, data,
                label=permutedims(hdrs[1:min(n_cols, length(hdrs))]),
                xlabel="Tick", ylabel="Value",
                title=name, linewidth=1.5,
                legend=:outertopright, size=(700, 400))
        else
            nh = min(n_cols, length(hdrs))
            plots_vec = [plot(ticks, data[:, j], label=hdrs[j], xlabel="Tick", linewidth=1.5) for j in 1:nh]
            p1 = plot(plots_vec..., layout=(nh, 1), size=(700, 200*nh), legend=:topright)
        end
        savefig(p1, joinpath(outdir, "plot_timeseries.png"))

        # ── Plot 2: Ensemble ──
        has_seed = ParamsType !== nothing && hasfield(ParamsType, :seed)
        if has_seed
            all_trajs = []
            for seed in 1:10
                _, traj = run_fn(params=ParamsType(; seed=seed))
                push!(all_trajs, reduce(hcat, traj)')
            end
            min_len = minimum(size(t, 1) for t in all_trajs)
            ticks_ens = 0:min_len-1
            var1 = hcat([t[1:min_len, 1] for t in all_trajs]...)
            mean_v = vec(mean(var1, dims=2))
            std_v  = vec(std(var1, dims=2))

            first_hdr = isempty(hdrs) ? "var1" : hdrs[1]
            p2 = plot(ticks_ens, mean_v,
                ribbon=std_v, fillalpha=0.3,
                label="Mean ± SD",
                xlabel="Tick", ylabel=first_hdr,
                title="$name: Ensemble (n=10)",
                linewidth=2, size=(700, 400))
            savefig(p2, joinpath(outdir, "plot_ensemble.png"))
        end

        # ── Plot 3: Sensitivity ──
        if sens_param !== nothing && has_seed && !isempty(hdrs)
            dval = sens_type == "Int" ? parse(Int, sens_default) : parse(Float64, sens_default)
            if sens_type == "Int"
                low  = max(1, dval ÷ 2)
                high = dval * 2
                vals = [low, dval, high]
            else
                low  = round(dval * 0.5; digits=4)
                high = round(dval < 50.0 ? min(dval * 2.0, 100.0) : dval * 1.5; digits=4)
                vals = [low, dval, high]
            end

            p3 = plot(title="$name: Effect of $sens_param",
                xlabel="Tick", ylabel=hdrs[1],
                legend=:outertopright, size=(700, 400))
            for val in vals
                kwargs = Dict{Symbol,Any}(Symbol(sens_param) => val)
                _, traj = run_fn(params=ParamsType(; kwargs...))
                d = reduce(hcat, traj)'
                plot!(p3, 0:size(d,1)-1, d[:, 1],
                    label="$sens_param=$val", linewidth=1.5)
            end
            savefig(p3, joinpath(outdir, "plot_sensitivity.png"))
        end

        global succeeded += 1
        println("✓")
    catch e
        push!(failed, name)
        println("FAIL: ", sprint(showerror, e))
    end
end

println("\n=== Pre-render complete ===")
println("Succeeded: $succeeded / $total")
if !isempty(failed)
    println("Failed: ", join(failed, ", "))
end
