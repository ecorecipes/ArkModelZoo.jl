"""
    ArkModelZoo Calibration Tests

Compares Ark.jl model ports against Java NetLogo originals using the
NetLogoCompare.jl statistical comparison framework.

Usage:
    julia --project=. test/calibrate.jl                  # run all
    julia --project=. test/calibrate.jl fire              # run one
    julia --project=. test/calibrate.jl fire,decay,ising  # run several
"""

# ── Load comparison framework ────────────────────────────────────────
const NETLOGO_JL_DIR = "/Users/username/Projects/netlogo/NetLogo.jl"
include(joinpath(NETLOGO_JL_DIR, "eval", "NetLogoCompare.jl"))
using .NetLogoCompare

using Pkg
Pkg.activate("/Users/username/Projects/ecs/ArkModelZoo.jl")
using ArkModelZoo, Ark

# ── Registry: map NetLogo model names to Ark run functions ───────────
#
# Each entry: (netlogo_model_file, ark_run_fn, ark_params_maker,
#              global_name => ark_column_index)
# The global_name must exactly match the NetLogo tracked_globals entries.
# The ark_column_index is 1-based into the Ark trajectory row tuple.

const MODEL_REGISTRY = Dict{String, NamedTuple}()

function register_model!(netlogo_file::String;
                         run_fn::Function,
                         params_fn::Function,
                         mapping::Dict{String,Int},
                         nl_model_type::Union{Symbol,Nothing}=nothing)
    MODEL_REGISTRY[netlogo_file] = (run_fn=run_fn, params_fn=params_fn, mapping=mapping,
                                     nl_model_type=nl_model_type)
end

# ── Helper: run Ark batches → TrajectoryData ─────────────────────────
function run_ark_batch(reg, seeds::Vector{Int}, nticks::Int)
    trajs = NetLogoCompare.TrajectoryData[]
    for seed in seeds
        params = reg.params_fn(seed, nticks)
        _, traj = reg.run_fn(; params=params, observe=true)
        vals = Dict{String, Vector{Float64}}()
        for (gname, col) in reg.mapping
            series = Float64[Float64(row[col]) for row in traj]
            vals[gname] = series
        end
        push!(trajs, NetLogoCompare.TrajectoryData(seed, collect(0:length(traj)-1), vals))
    end
    trajs
end

# ── Calibration runner ───────────────────────────────────────────────
function calibrate(netlogo_file::String; n_per_batch::Int=30)
    haskey(MODEL_REGISTRY, netlogo_file) || error("No Ark adapter for '$netlogo_file'")
    reg = MODEL_REGISTRY[netlogo_file]

    # Load the NetLogo model wrapper (must eval in NetLogoCompare to avoid world-age errors)
    mpath = joinpath(NETLOGO_JL_DIR, "eval", "models", "$netlogo_file.jl")
    isfile(mpath) || error("NetLogo model file not found: $mpath")
    Base.eval(NetLogoCompare, :(include($mpath)))

    # Get the model instance — use explicit type if provided, else auto-discover
    model = nothing
    if reg.nl_model_type !== nothing
        model = getfield(NetLogoCompare, reg.nl_model_type)()
    else
        # Auto-discover: look in Main for the struct just included from the model file
        fn_norm = lowercase(replace(netlogo_file, "_"=>""))
        for sym in names(Main; all=true)
            obj = try getfield(Main, sym) catch; nothing end
            obj === nothing && continue
            if obj isa Type && obj <: AbstractBenchmarkModel && obj !== AbstractBenchmarkModel
                sn = lowercase(replace(string(sym), "Model"=>""))
                if sn == fn_norm
                    model = obj()
                    break
                end
            end
        end
        # Fallback: check NetLogoCompare exports by type name
        if model === nothing
            for sym in names(NetLogoCompare; all=true)
                obj = try getfield(NetLogoCompare, sym) catch; nothing end
                obj === nothing && continue
                if obj isa Type && obj <: AbstractBenchmarkModel && obj !== AbstractBenchmarkModel
                    sn = lowercase(replace(string(sym), "Model"=>""))
                    if sn == fn_norm
                        model = obj()
                        break
                    end
                end
            end
        end
    end

    model === nothing && error("Could not find model struct for '$netlogo_file'")

    nticks = n_ticks(model)
    mname = model_name(model)
    seeds_a = collect(1:n_per_batch)
    seeds_b = collect(n_per_batch+1:2*n_per_batch)

    println("\n╔══════════════════════════════════════════════════════════╗")
    println("║  Calibrating: $mname ($netlogo_file)")
    println("║  4 batches × $n_per_batch reps  │  Ticks: $nticks")
    println("╚══════════════════════════════════════════════════════════╝")

    print("  ▶ Ark batch A+B...")
    t_ark = @elapsed begin
        ark_a = run_ark_batch(reg, seeds_a, nticks)
        ark_b = run_ark_batch(reg, seeds_b, nticks)
    end
    println(" $(round(t_ark, digits=1))s")

    print("  ▶ Java batch A+B...")
    t_jv = @elapsed begin
        jv_a = NetLogoCompare.run_java_trajectories(model, seeds_a)
        jv_b = NetLogoCompare.run_java_trajectories(model, seeds_b)
    end
    println(" $(round(t_jv, digits=1))s")

    globals = tracked_globals(model)
    all_pass = true

    for g in globals
        haskey(reg.mapping, g) || (println("    ⚠ No mapping for '$g' — skipped"); continue)

        ark_ark = NetLogoCompare.batch_metrics(ark_a, ark_b, g, nticks)
        jv_jv   = NetLogoCompare.batch_metrics(jv_a, jv_b, g, nticks)
        ark_jv  = NetLogoCompare.batch_metrics(ark_a, jv_a, g, nticks)

        # Pass: cross-impl MAE ≤ max(within) * tolerance
        tol = 2.5
        baseline_mae = max(ark_ark.mae, jv_jv.mae, 1e-6)
        baseline_ks  = max(ark_ark.ks,  jv_jv.ks,  0.05)

        pass_mae = isnan(ark_jv.mae) || ark_jv.mae <= baseline_mae * tol
        pass_ks  = isnan(ark_jv.ks)  || ark_jv.ks  <= max(baseline_ks * tol, 0.35)
        pass = pass_mae && pass_ks

        all_pass &= pass
        sym = pass ? "✓" : "✗"
        println("    $sym $g: MAE within=($(round(ark_ark.mae,digits=3)),$(round(jv_jv.mae,digits=3))) cross=$(round(ark_jv.mae,digits=3)) KS=$(round(ark_jv.ks,digits=3))")
    end

    status = all_pass ? "✓ PASS" : "✗ FAIL"
    println("  $status: $mname\n")
    return (name=mname, pass=all_pass)
end

# ══════════════════════════════════════════════════════════════════════
# MODEL REGISTRATIONS
# ══════════════════════════════════════════════════════════════════════

# Fire (initial-trees, burned-trees)
register_model!("fire";
    run_fn=run_fire,
    params_fn=(s,t)->FireParams(max_ticks=t, seed=s),
    mapping=Dict("initial-trees"=>1, "burned-trees"=>2),
    nl_model_type=:FireModel)

# Segregation (percent-similar, percent-unhappy)
register_model!("segregation";
    run_fn=run_segregation,
    params_fn=(s,t)->SegregationParams(max_ticks=t, seed=s),
    mapping=Dict("percent-similar"=>1, "percent-unhappy"=>2),
    nl_model_type=:SegregationModel)

# Virus (num-susceptible, num-infected, num-resistant)
register_model!("virus";
    run_fn=run_virus,
    params_fn=(s,t)->VirusParams(max_ticks=t, seed=s),
    mapping=Dict("num-susceptible"=>1, "num-infected"=>2, "num-resistant"=>3))

# Wolf-Sheep (Ark: Sheep=1, Wolves=2, Grass=3; NL: num-wolves, num-sheep, num-grass)
register_model!("wolfsheep";
    run_fn=run_wolfsheep,
    params_fn=(s,t)->WolfSheepParams(max_ticks=t, seed=s),
    mapping=Dict("num-wolves"=>2, "num-sheep"=>1, "num-grass"=>3))

# Ants (total-food)
register_model!("ants";
    run_fn=run_ants,
    params_fn=(s,t)->AntsParams(max_ticks=t, seed=s),
    mapping=Dict("total-food"=>2))

# Decay (decays)
register_model!("decay";
    run_fn=run_decay,
    params_fn=(s,t)->DecayParams(max_ticks=t, seed=s),
    mapping=Dict("decays"=>1))

# Diffusion (max-temp, mean-temp)
register_model!("diffusion";
    run_fn=run_diffusion,
    params_fn=(s,t)->DiffusionParams(max_ticks=t, seed=s),
    mapping=Dict("max-temp"=>1, "mean-temp"=>2))

# Ising (sum-of-spins)
register_model!("ising";
    run_fn=run_ising,
    params_fn=(s,t)->IsingParams(max_ticks=t, seed=s),
    mapping=Dict("sum-of-spins"=>1))

# Contact Process (p-occupied)
register_model!("contactprocess";
    run_fn=run_contactprocess,
    params_fn=(s,t)->ContactProcessParams(max_ticks=t, seed=s),
    mapping=Dict("p-occupied"=>1))

# Fire Percolation (fire-size)
register_model!("firepercolation";
    run_fn=run_firepercolation,
    params_fn=(s,t)->FirePercolationParams(max_ticks=t, seed=s),
    mapping=Dict("fire-size"=>1))

# Voter (n-colors)
register_model!("voter";
    run_fn=run_voter,
    params_fn=(s,t)->VoterParams(max_ticks=t, seed=s),
    mapping=Dict("n-colors"=>1))

# Flocking (avg-heading)
register_model!("flocking";
    run_fn=run_flocking,
    params_fn=(s,t)->FlockingParams(max_ticks=t, seed=s),
    mapping=Dict("avg-heading"=>1))

# SIR (num-susceptible, num-infected, num-recovered)
register_model!("sir";
    run_fn=run_sir,
    params_fn=(s,t)->SIRParams(max_ticks=t, seed=s),
    mapping=Dict("num-susceptible"=>1, "num-infected"=>2, "num-recovered"=>3))

# Birth Rates (red-count, blue-count)
register_model!("simple_birth_rates";
    run_fn=run_birthrates,
    params_fn=(s,t)->BirthRatesParams(max_ticks=t, seed=s),
    mapping=Dict("red-count"=>1, "blue-count"=>2),
    nl_model_type=:BirthRatesModel)

# El Farol (attendance)
register_model!("el_farol";
    run_fn=run_elfarol,
    params_fn=(s,t)->ElFarolParams(max_ticks=t, seed=s),
    mapping=Dict("attendance"=>1))

# Grass-Brush-Trees (n-trees)
register_model!("grassbrushtrees";
    run_fn=run_gbt,
    params_fn=(s,t)->GBTParams(max_ticks=t, seed=s),
    mapping=Dict("n-trees"=>1))

# Coordination (n-norm1)
register_model!("coordination";
    run_fn=run_coordination,
    params_fn=(s,t)->CoordinationParams(max_ticks=t, seed=s),
    mapping=Dict("n-norm1"=>1))

# COIN (current-utility)
register_model!("coin";
    run_fn=run_coin,
    params_fn=(s,t)->CoinParams(max_ticks=t, seed=s),
    mapping=Dict("current-utility"=>1))

# PD Simple (n-cooperators)
register_model!("pd_simple";
    run_fn=run_pdsimple,
    params_fn=(s,t)->PDSimpleParams(max_ticks=t, seed=s),
    mapping=Dict("n-cooperators"=>1))

# IPD (mean-score)
register_model!("ipd";
    run_fn=run_ipd,
    params_fn=(s,t)->IPDParams(max_ticks=t, seed=s),
    mapping=Dict("mean-score"=>1))

# Contagion SI (n-infected)
register_model!("contagion_si";
    run_fn=run_contagionsi,
    params_fn=(s,t)->ContagionSIParams(max_ticks=t, seed=s),
    mapping=Dict("n-infected"=>1))

# Contagion SIR (n-infected, n-immune)
register_model!("contagion_sir";
    run_fn=run_contagionsir,
    params_fn=(s,t)->ContagionSIRParams(max_ticks=t, seed=s),
    mapping=Dict("n-infected"=>1, "n-immune"=>2))

# Wealth Distribution (gini-index-reserve)
register_model!("wealth_distribution";
    run_fn=run_wealthdistribution,
    params_fn=(s,t)->WDParams(max_ticks=t, seed=s),
    mapping=Dict("gini-index-reserve"=>1),
    nl_model_type=:WealthDistModel)

# Particles (collisions)
register_model!("particles";
    run_fn=run_particles,
    params_fn=(s,t)->ParticlesParams(max_ticks=t, seed=s),
    mapping=Dict("collisions"=>1))

# Opinion BC (mean-opinion, sd-opinion)
register_model!("opinion_bc";
    run_fn=run_opinionbc,
    params_fn=(s,t)->OpinionBCParams(max_ticks=t, seed=s),
    mapping=Dict("mean-opinion"=>1, "sd-opinion"=>2))

# Bayesian (prob-true)
register_model!("bayesian";
    run_fn=run_bayesian,
    params_fn=(s,t)->BayesianParams(max_ticks=t, seed=s),
    mapping=Dict("prob-true"=>1))

# Coordination 2 Groups (n-norm1)
register_model!("coordination_2groups";
    run_fn=run_coordination2groups,
    params_fn=(s,t)->Coordination2GroupsParams(max_ticks=t, seed=s),
    mapping=Dict("n-norm1"=>1))

# Climate Change (temperature)
register_model!("climate_change";
    run_fn=run_climatechange,
    params_fn=(s,t)->ClimateChangeParams(max_ticks=t, seed=s),
    mapping=Dict("temperature"=>1),
    nl_model_type=:ClimateModel)

# Team Assembly (giant-component-size)
register_model!("team_assembly";
    run_fn=run_teamassembly,
    params_fn=(s,t)->TeamAssemblyParams(max_ticks=t, seed=s),
    mapping=Dict("giant-component-size"=>1))

# Party (boring-groups)
register_model!("party";
    run_fn=run_party,
    params_fn=(s,t)->PartyParams(max_ticks=t, seed=s),
    mapping=Dict("boring-groups"=>1))

# Pareto Learning (eu-cooperate, eu-defect)
register_model!("paretolearn";
    run_fn=run_paretolearn,
    params_fn=(s,t)->ParetoLearnParams(max_ticks=t, seed=s),
    mapping=Dict("eu-cooperate"=>1, "eu-defect"=>2))

# Boiling (avg-heat)
register_model!("boiling";
    run_fn=run_boiling,
    params_fn=(s,t)->BoilingParams(max_ticks=t, seed=s),
    mapping=Dict("avg-heat"=>1))

# Crystallization (ave-metal-temp, num-frozen)
register_model!("crystallization";
    run_fn=run_crystallization,
    params_fn=(s,t)->CrystallizationParams(max_ticks=t, seed=s),
    mapping=Dict("ave-metal-temp"=>1, "num-frozen"=>2))

# Sand (n-brown)
register_model!("sand";
    run_fn=run_sand,
    params_fn=(s,t)->SandParams(max_ticks=t, seed=s),
    mapping=Dict("n-brown"=>1))

# Solid Diffusion (n-turtles)
register_model!("solid_diffusion";
    run_fn=run_soliddiffusion,
    params_fn=(s,t)->SolidDiffusionParams(max_ticks=t, seed=s),
    mapping=Dict("n-turtles"=>1))

# DLA Simple (n-remaining)
register_model!("dla_simple";
    run_fn=run_dlasimple,
    params_fn=(s,t)->DLAsParams(max_ticks=t, seed=s),
    mapping=Dict("n-remaining"=>1))

# Rope (n-visible)
register_model!("rope";
    run_fn=run_rope,
    params_fn=(s,t)->RopeParams(max_ticks=t),
    mapping=Dict("n-visible"=>1))

# Polymer Dynamics (n-turtles)
register_model!("polymer_dynamics";
    run_fn=run_polymerdynamics,
    params_fn=(s,t)->PolymerDynamicsParams(max_ticks=t, seed=s),
    mapping=Dict("n-turtles"=>1))

# Thermostat (temperature)
register_model!("thermostat";
    run_fn=run_thermostat,
    params_fn=(s,t)->ThermostatParams(max_ticks=t, seed=s),
    mapping=Dict("temperature"=>1))

# Mimicry (n-monarchs, n-viceroys, n-birds)
register_model!("mimicry";
    run_fn=run_mimicry,
    params_fn=(s,t)->MimicryParams(max_ticks=t, seed=s),
    mapping=Dict("n-monarchs"=>1, "n-viceroys"=>2, "n-birds"=>3))

# Mousetraps (traps-triggered, balls-in-air)
register_model!("mousetraps";
    run_fn=run_mousetraps,
    params_fn=(s,t)->MousetrapParams(max_ticks=t, seed=s),
    mapping=Dict("traps-triggered"=>1, "balls-in-air"=>2))

# Axelrod Cultural (number_of_cultures, number_of_active_agents)
register_model!("axelrod_cultural";
    run_fn=run_axelrodcultural,
    params_fn=(s,t)->AxelrodParams(max_ticks=t, seed=s),
    mapping=Dict("number_of_cultures"=>1, "number_of_active_agents"=>2))

# Evolution of Norms (mn, sd)
register_model!("evolution_of_norms";
    run_fn=run_evolutionofnorms,
    params_fn=(s,t)->NormParams(max_ticks=t, seed=s),
    mapping=Dict("mn"=>1, "sd"=>2))

# Language Borders (avg-language)
register_model!("language_borders";
    run_fn=run_languageborders,
    params_fn=(s,t)->LanguageBordersParams(max_ticks=t, seed=s),
    mapping=Dict("avg-language"=>1))

# Being Green (n-action-takers)
register_model!("being_green";
    run_fn=run_beinggreen,
    params_fn=(s,t)->BeingGreenParams(max_ticks=t, seed=s),
    mapping=Dict("n-action-takers"=>1))

# Tourism (attendance, reputation)
register_model!("tourism";
    run_fn=run_tourism,
    params_fn=(s,t)->TourismParams(max_ticks=t, seed=s),
    mapping=Dict("attendance"=>1, "reputation"=>2))

# Civilization Growth (n-civs)
register_model!("civilization_growth";
    run_fn=run_civilizationgrowth,
    params_fn=(s,t)->CivGrowthParams(max_ticks=t, seed=s),
    mapping=Dict("n-civs"=>1))

# Lassa Virus (pct_infected, pct_immune, current_cases, total_fatalities)
register_model!("lassa_virus";
    run_fn=run_lassavirus,
    params_fn=(s,t)->LassaParams(max_ticks=t, seed=s),
    mapping=Dict("pct_infected"=>1, "pct_immune"=>2, "current_cases"=>3, "total_fatalities"=>4))

# Modsoc Segregation (average-similarity, unhappiness)
register_model!("modsoc_segregation";
    run_fn=run_modsocsegregation,
    params_fn=(s,t)->ModsocSegParams(max_ticks=t, seed=s),
    mapping=Dict("average-similarity"=>1, "unhappiness"=>2))

# Unit Cohesion (n-vacancies)
register_model!("unit_cohesion";
    run_fn=run_unitcohesion,
    params_fn=(s,t)->UnitCohesionParams(max_ticks=t, seed=s),
    mapping=Dict("n-vacancies"=>1))

# Dating (n-paired)
register_model!("dating";
    run_fn=run_dating,
    params_fn=(s,t)->DatingParams(max_ticks=t, seed=s),
    mapping=Dict("n-paired"=>1))

# Drug Use (number-overdoses)
register_model!("drug_use";
    run_fn=run_druguse,
    params_fn=(s,t)->DrugUseParams(max_ticks=t, seed=s),
    mapping=Dict("number-overdoses"=>1))

# Marriage (num-bachelors)
register_model!("marriage";
    run_fn=run_marriage,
    params_fn=(s,t)->MarriageParams(max_ticks=t, seed=s),
    mapping=Dict("num-bachelors"=>1))

# Ant System (best-tour-cost)
register_model!("antsystem";
    run_fn=run_antsystem,
    params_fn=(s,t)->AntSystemParams(max_ticks=t, seed=s),
    mapping=Dict("best-tour-cost"=>1))

# Mailmen (total-dist, num-remaining)
register_model!("mailmen";
    run_fn=run_mailmen,
    params_fn=(s,t)->MailmenParams(max_ticks=t, seed=s),
    mapping=Dict("total-dist"=>1, "num-remaining"=>2))

# Infinite Life (count cells)
register_model!("infinite_life";
    run_fn=run_infinitelife,
    params_fn=(s,t)->InfLifeParams(max_ticks=t, seed=s),
    mapping=Dict("count cells"=>1))

# Fire Benchmark (burned-trees, burning-count)
register_model!("fire_benchmark";
    run_fn=run_firebenchmark,
    params_fn=(s,t)->FBParams(max_ticks=t, seed=s),
    mapping=Dict("burned-trees"=>1, "burning-count"=>2))

# Tumor (cell-count)
register_model!("tumor";
    run_fn=run_tumor,
    params_fn=(s,t)->TumorParams(max_ticks=t, seed=s),
    mapping=Dict("cell-count"=>1))

# Daisyworld (Note: check header ordering)
register_model!("daisyworld";
    run_fn=run_daisyworld,
    params_fn=(s,t)->DaisyworldParams(max_ticks=t, seed=s),
    mapping=Dict("global-temperature"=>1))

# Ethnocentrism (count turtles)
register_model!("ethnocentrism";
    run_fn=run_ethnocentrism,
    params_fn=(s,t)->EthnocentrismParams(max_ticks=t, seed=s),
    mapping=Dict("count turtles"=>1))

# Schelling (percent-similar, percent-unhappy)
register_model!("schelling";
    run_fn=run_schelling,
    params_fn=(s,t)->SchParams(max_ticks=t, seed=s),
    mapping=Dict("percent-similar"=>1, "percent-unhappy"=>2))

# Fake News (pct-aware, pct-unaware)
register_model!("fake_news";
    run_fn=run_fakenews,
    params_fn=(s,t)->FNewsParams(max_ticks=t, seed=s),
    mapping=Dict("pct-aware"=>1, "pct-unaware"=>2))

# SuperDiffuser (current-adopted)
register_model!("superdiffuser";
    run_fn=run_superdiffuser,
    params_fn=(s,t)->SDiffParams(max_ticks=t, seed=s),
    mapping=Dict("current-adopted"=>1))

# Slow Spread (pct-green, pct-grey)
register_model!("slow_spread";
    run_fn=run_slowspread,
    params_fn=(s,t)->SSpreadParams(max_ticks=t, seed=s),
    mapping=Dict("pct-green"=>1, "pct-grey"=>2))

# Spreading Groups (num-infected)
register_model!("spreading_groups";
    run_fn=run_spreadinggroups,
    params_fn=(s,t)->SGroupParams(max_ticks=t, seed=s),
    mapping=Dict("num-infected"=>1))

# Products Market (count-apple, count-samsung)
register_model!("products_market";
    run_fn=run_productsmarket,
    params_fn=(s,t)->PMktParams(max_ticks=t, seed=s),
    mapping=Dict("count-apple"=>1, "count-samsung"=>2),
    nl_model_type=:ProductsModel)

# Social Influence (number-influence)
register_model!("social_influence";
    run_fn=run_socialinfluence,
    params_fn=(s,t)->SInflParams(max_ticks=t, seed=s),
    mapping=Dict("number-influence"=>1))

# Info Diffusion (num-believers, num-factcheckers, num-susceptibles)
register_model!("info_diffusion";
    run_fn=run_infodiffusion,
    params_fn=(s,t)->InfoDiffParams(max_ticks=t, seed=s),
    mapping=Dict("num-believers"=>1, "num-factcheckers"=>2, "num-susceptibles"=>3))

# Minority Belief (n-magenta, n-yellow, n-cyan)
register_model!("minority_belief";
    run_fn=run_minoritybelief,
    params_fn=(s,t)->MBeliefParams(max_ticks=t, seed=s),
    mapping=Dict("n-magenta"=>1, "n-yellow"=>2, "n-cyan"=>3))

# Recruiting (recruitpct, resistpct, neutralpct — but Ark may have different columns)
register_model!("recruiting";
    run_fn=run_recruiting,
    params_fn=(s,t)->RecParams(max_ticks=t, seed=s),
    mapping=Dict("recruitpct"=>1, "resistpct"=>2))

# Recruiting Supporters (recruitpct, resistpct, neutralpct)
register_model!("recruiting_supporters";
    run_fn=run_recruitingsupporters,
    params_fn=(s,t)->RecSupParams(max_ticks=t, seed=s),
    mapping=Dict("recruitpct"=>1))

# Bullwhip Effect (count customers, STOCKS)
register_model!("bullwhip_effect";
    run_fn=run_bullwhip,
    params_fn=(s,t)->BullwhipParams(num_ticks=t, seed=s),
    mapping=Dict("count customers"=>1))

# Privacy Opinion (adoptersTotal, adopterPercent)
register_model!("privacy_opinion";
    run_fn=run_privacyopinion,
    params_fn=(s,t)->PrvParams(max_ticks=t, seed=s),
    mapping=Dict("adoptersTotal"=>1, "adopterPercent"=>2))

# Crop Rotation (n-active)  — NL tracked_globals is complex reporter
register_model!("crop_rotation";
    run_fn=run_croprotation,
    params_fn=(s,t)->CRParams(max_ticks=t, seed=s),
    mapping=Dict("n-active"=>1))

# Voronoi Voter (n-colors)
register_model!("voronoi_voter";
    run_fn=run_voronoivoter,
    params_fn=(s,t)->VoronoiVoterParams(max_ticks=t, seed=s),
    mapping=Dict("n-colors"=>1))

# Contagion NW (num-infected-nw, num-links-nw)
register_model!("contagion_nw";
    run_fn=run_contagionnw,
    params_fn=(s,t)->ContagionNWParams(max_ticks=t, seed=s),
    mapping=Dict("num-infected-nw"=>1, "num-links-nw"=>2))

# Pref Attach Homophily (number-homophily, count links)
register_model!("pref_attach_homophily";
    run_fn=run_prefattachhomophily,
    params_fn=(s,t)->PrefAttachHomophilyParams(max_ticks=t, seed=s),
    mapping=Dict("number-homophily"=>1, "count links"=>2))

# Diffusion Network (num-red-dn, num-grey-dn)
register_model!("diffusion_network";
    run_fn=run_diffusionnetwork,
    params_fn=(s,t)->DiffusionNetworkParams(max_ticks=t, seed=s),
    mapping=Dict("num-red-dn"=>1, "num-grey-dn"=>2))

# Social Network Diffusion (num-red, num-grey, avg-utility)
register_model!("social_network_diffusion";
    run_fn=run_socialnetworkdiffusion,
    params_fn=(s,t)->SocialNetDiffParams(max_ticks=t, seed=s),
    mapping=Dict("num-red"=>1, "num-grey"=>2, "avg-utility"=>3))

# Minimal SIS (reproduction-number, new-infected)
register_model!("minimal_sis";
    run_fn=run_minimalsis,
    params_fn=(s,t)->MinimalSISParams(max_ticks=t, seed=s),
    mapping=Dict("reproduction-number"=>1, "new-infected"=>2))

# Flocking Network (num-links-fn, avg-heading-fn)
register_model!("flocking_network";
    run_fn=run_flockingnetwork,
    params_fn=(s,t)->FlockingNetworkParams(max_ticks=t, seed=s),
    mapping=Dict("num-links-fn"=>1, "avg-heading-fn"=>2))

# Cultural Diffusion (num-iter, total-langs-cd)
register_model!("cultural_diffusion";
    run_fn=run_culturaldiffusion,
    params_fn=(s,t)->CulturalDiffusionParams(max_ticks=t, seed=s),
    mapping=Dict("num-iter"=>1, "total-langs-cd"=>2))

# Drug Use Overdose (number-overdoses, num-drug-users, num-alive)
register_model!("drug_use_overdose";
    run_fn=run_druguseoverdose,
    params_fn=(s,t)->DrugUseOverdoseParams(max_ticks=t, seed=s),
    mapping=Dict("number-overdoses"=>1, "num-drug-users"=>2, "num-alive"=>3))

# Spatial Opinion (fizz, left-freq, right-freq)
register_model!("spatial_opinion";
    run_fn=run_spatialopinion,
    params_fn=(s,t)->SOpnParams(max_ticks=t, seed=s),
    mapping=Dict("fizz"=>1, "left-freq"=>2, "right-freq"=>3))

# Spatial Attitude (fizz, left-freq, right-freq)
register_model!("spatial_attitude";
    run_fn=run_spatialattitude,
    params_fn=(s,t)->SAttParams(max_ticks=t, seed=s),
    mapping=Dict("fizz"=>1, "left-freq"=>2, "right-freq"=>3))

# Spreading Bots (num-infected)
register_model!("spreading_bots";
    run_fn=run_spreadingbots,
    params_fn=(s,t)->SBotParams(max_ticks=t, seed=s),
    mapping=Dict("num-infected"=>1))

# Misinformation SBFC (num-believers-sbfc, num-factcheckers-sbfc, num-susceptibles-sbfc)
register_model!("misinformation_sbfc";
    run_fn=run_misinformationsbfc,
    params_fn=(s,t)->MisSBFCParams(max_ticks=t, seed=s),
    mapping=Dict("num-believers-sbfc"=>1, "num-factcheckers-sbfc"=>2, "num-susceptibles-sbfc"=>3))

# Disinfo NW Bitstring (times-heard-from-elites, times-heard-from-social, times-traded-up, times-created-rumor)
register_model!("disinfo_nw_bitstring";
    run_fn=run_disinfobitstringnw,
    params_fn=(s,t)->DisBitParams(max_ticks=t, seed=s),
    mapping=Dict("times-heard-from-elites"=>1, "times-heard-from-social"=>2, "times-traded-up"=>3, "times-created-rumor"=>4))

# Participatory Disinfo (times-heard-from-elites, times-heard-from-social, times-traded-up, times-created-rumor)
register_model!("participatory_disinfo";
    run_fn=run_participatorydisinfo,
    params_fn=(s,t)->PDisParams(max_ticks=t, seed=s),
    mapping=Dict("times-heard-from-elites"=>1, "times-heard-from-social"=>2, "times-traded-up"=>3, "times-created-rumor"=>4))

# BlackBox (Q4t, Q3t)
register_model!("blackbox";
    run_fn=run_blackbox,
    params_fn=(s,t)->BBoxParams(max_ticks=t, seed=s),
    mapping=Dict("Q4t"=>1, "Q3t"=>2))

# CSV Population (total-energy, avg-age, pop-count)
register_model!("csv_population";
    run_fn=run_csvpopulation,
    params_fn=(s,t)->CsvPopParams(max_ticks=t, seed=s),
    mapping=Dict("total-energy"=>1, "avg-age"=>2, "pop-count"=>3))

# Traffic Basic (mean-speed)
register_model!("traffic_basic";
    run_fn=run_trafficbasic,
    params_fn=(s,t)->TBParams(max_ticks=t, seed=s),
    mapping=Dict("mean-speed"=>1))

# Rumor Mill (clique)
register_model!("rumor_mill";
    run_fn=run_rumormill,
    params_fn=(s,t)->RMParams(max_ticks=t, seed=s),
    mapping=Dict("clique"=>1))

# Forest Dewdney (local-richness, sp)
register_model!("forest_dewdney";
    run_fn=run_forestdewdney,
    params_fn=(s,t)->FDParams(max_ticks=t, seed=s),
    mapping=Dict("local-richness"=>1, "sp"=>2))

# Sugarscape Culture (num-red-sc, num-blue-sc)
register_model!("sugarscape_culture";
    run_fn=run_sugarscapeculture,
    params_fn=(s,t)->SCParams(max_ticks=t, seed=s),
    mapping=Dict("num-red-sc"=>1, "num-blue-sc"=>2))

# Sugarscape Sexual (count turtles)
register_model!("sugarscape_sexual";
    run_fn=run_sugarscapesexual,
    params_fn=(s,t)->SSParams(max_ticks=t, seed=s),
    mapping=Dict("count turtles"=>1))

# CSV Network Foraging (total-supply, num-consumers, total-consumed)
register_model!("csv_network_foraging";
    run_fn=run_csvnetworkforaging,
    params_fn=(s,t)->CNFParams(max_ticks=t, seed=s),
    mapping=Dict("total-supply"=>1, "num-consumers"=>2, "total-consumed"=>3))

# CQIN (num-updated, num-resistant, num-adjusted)
register_model!("cqin";
    run_fn=run_cqin,
    params_fn=(s,t)->CQINParams(max_ticks=t, seed=s),
    mapping=Dict("num-updated"=>1, "num-resistant"=>2, "num-adjusted"=>3))

# Fungal Bioremediation (num-fungi-fb, num-enzymes-fb, num-ecs-fb)
register_model!("fungal_bioremediation";
    run_fn=run_fungalbioremediation,
    params_fn=(s,t)->FBRParams(max_ticks=t, seed=s),
    mapping=Dict("num-fungi-fb"=>1, "num-enzymes-fb"=>2, "num-ecs-fb"=>3))

# Competition Learning (mean-strategy-cl, min-strategy-cl)
register_model!("competition_learning";
    run_fn=run_competitionlearning,
    params_fn=(s,t)->CLParams(max_ticks=t, seed=s),
    mapping=Dict("mean-strategy-cl"=>1, "min-strategy-cl"=>2),
    nl_model_type=:CompetitionLearningModel)

# Simple Market (active-shoppers, empty-traders)
register_model!("simple_market";
    run_fn=run_simplemarket,
    params_fn=(s,t)->SMktParams(max_ticks=t, seed=s),
    mapping=Dict("active-shoppers"=>1, "empty-traders"=>2),
    nl_model_type=:SimpleMarketModel)

# Simple Market Random (num-shoppers-left, num-traders-with-stock)
register_model!("simple_market_random";
    run_fn=run_simplemarketrandom,
    params_fn=(s,t)->SMktRParams(max_ticks=t, seed=s),
    mapping=Dict("num-shoppers-left"=>1, "num-traders-with-stock"=>2),
    nl_model_type=:SimpleMarketRandomModel)

# Simple Market Table (count shoppers, sum [paces] of shoppers)
register_model!("simple_market_table";
    run_fn=run_simplemarkettable,
    params_fn=(s,t)->SMktTParams(max_ticks=t, seed=s),
    mapping=Dict("count shoppers"=>1, "sum [paces] of shoppers"=>2),
    nl_model_type=:SimpleMarketTableModel)

# Babysitting Coop (total-scrip, going-out-count, sitting-count)
register_model!("babysitting_coop";
    run_fn=run_babysittingcoop,
    params_fn=(s,t)->BSitParams(max_ticks=t, seed=s),
    mapping=Dict("total-scrip"=>1, "going-out-count"=>2, "sitting-count"=>3),
    nl_model_type=:BabySittingModel)

# Leonardi Tech Adoption (count people with [not empty? usage], count people with [persistence > 0])
register_model!("leonardi_tech_adoption";
    run_fn=run_leonarditechadoption,
    params_fn=(s,t)->LTechParams(max_ticks=t, seed=s),
    mapping=Dict("count people with [not empty? usage]"=>1, "count people with [persistence > 0]"=>2),
    nl_model_type=:LeonardiTechAdoptionModel)

# Wisdom of Crowd (cnt-offenders, cnt-inter, cnt-neutralized, curr-oi)
register_model!("wisdom_crowd";
    run_fn=run_wisdomcrowd,
    params_fn=(s,t)->WCParams(max_ticks=t, seed=s),
    mapping=Dict("cnt-offenders"=>1, "cnt-inter"=>2, "cnt-neutralized"=>3, "curr-oi"=>4),
    nl_model_type=:WisdomCrowdModel)

# Recruiting Movement (recruitpct, resistpct, neutralpct)
register_model!("recruiting_movement";
    run_fn=run_recruitingmovement,
    params_fn=(s,t)->RecMovParams(max_ticks=t, seed=s),
    mapping=Dict("recruitpct"=>1, "resistpct"=>2, "neutralpct"=>3),
    nl_model_type=:RecruitingMovementModel)

# ══════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════

function run_all_calibrations(; n_per_batch::Int=30)
    results = []
    for name in sort(collect(keys(MODEL_REGISTRY)))
        try
            r = calibrate(name; n_per_batch=n_per_batch)
            push!(results, r)
        catch e
            println("  ✗ ERROR $name: $(sprint(showerror, e))")
            push!(results, (name=name, pass=false))
        end
    end

    n_pass = count(r -> r.pass, results)
    println("\n════════════════════════════════════════════")
    println("  CALIBRATION: $n_pass/$(length(results)) PASS")
    println("════════════════════════════════════════════")
    for r in results
        println("  $(r.pass ? "✓" : "✗") $(r.name)")
    end
    results
end

if abspath(PROGRAM_FILE) == @__FILE__
    if isempty(ARGS)
        run_all_calibrations(; n_per_batch=20)
    else
        models = split(ARGS[1], ",")
        for m in models
            calibrate(String(strip(m)); n_per_batch=20)
        end
    end
end
