"""
    ArkModelZoo Performance Benchmarks

Measures wall-clock time for Ark.jl models and (optionally) compares against
Java NetLogo originals. Outputs a markdown-formatted results table.

Usage:
    julia --project=. test/benchmark.jl                  # all models, Ark only
    julia --project=. test/benchmark.jl --netlogo         # Ark + NetLogo comparison
    julia --project=. test/benchmark.jl fire,segregation  # specific models
    julia --project=. test/benchmark.jl --netlogo fire    # specific + NetLogo

Set `NETLOGO_JL_DIR` to a NetLogo.jl checkout to enable `--netlogo`.
"""

# ── Load frameworks ──────────────────────────────────────────────────
const REPO_ROOT = normpath(joinpath(@__DIR__, ".."))

function _find_netlogo_jl_dir()
    env_path = get(ENV, "NETLOGO_JL_DIR", "")
    candidates = filter(!isempty, [
        env_path,
        normpath(joinpath(REPO_ROOT, "..", "..", "netlogo", "NetLogo.jl")),
        normpath(joinpath(REPO_ROOT, "..", "NetLogo.jl")),
    ])
    for candidate in candidates
        isdir(candidate) && return candidate
    end
    return nothing
end

const NETLOGO_JL_DIR = _find_netlogo_jl_dir()

using Pkg
Pkg.activate(REPO_ROOT)
using ArkModelZoo, Ark
using Statistics

# ── Model registry for benchmarks ───────────────────────────────────
# Each entry: (run_fn, params_fn, n_ticks, description, category)
const BENCH_REGISTRY = Dict{String, NamedTuple}()

function register_bench!(name::String;
                         run_fn::Function,
                         params_fn::Function,
                         n_ticks::Int = 200,
                         description::String = "",
                         category::String = "other")
    BENCH_REGISTRY[name] = (run_fn=run_fn, params_fn=params_fn, n_ticks=n_ticks,
                            description=description, category=category)
end

# ── Ark-only benchmark ──────────────────────────────────────────────
function bench_ark(name::String; n_warmup::Int=1, n_runs::Int=5, seed::Int=42)
    reg = BENCH_REGISTRY[name]
    # Warmup
    for _ in 1:n_warmup
        params = reg.params_fn(seed, reg.n_ticks)
        reg.run_fn(; params=params, observe=true)
    end
    # Timed runs
    times = Float64[]
    allocs = Int[]
    for i in 1:n_runs
        stats = @timed begin
            params = reg.params_fn(seed + i, reg.n_ticks)
            reg.run_fn(; params=params, observe=true)
        end
        push!(times, stats.time)
        push!(allocs, Int(stats.bytes))
    end
    return (median_time=median(times), min_time=minimum(times),
            mean_time=mean(times), std_time=std(times),
            median_alloc=median(allocs), n_ticks=reg.n_ticks)
end

# ── NetLogo benchmark (via Java) ────────────────────────────────────
function _find_wrapper_file(name::String)
    NETLOGO_JL_DIR === nothing && return nothing
    models_dir = joinpath(NETLOGO_JL_DIR, "eval", "models")
    # Try exact match first
    p = joinpath(models_dir, "$name.jl")
    isfile(p) && return p
    # Try all .jl files — match by stripping underscores
    norm = lowercase(replace(name, "_" => ""))
    for f in readdir(models_dir)
        endswith(f, ".jl") || continue
        fnorm = lowercase(replace(f[1:end-3], "_" => ""))
        fnorm == norm && return joinpath(models_dir, f)
    end
    return nothing
end

# Lazily initialized NetLogoCompare module — loaded once, model files added incrementally
const _NLC_REF = Ref{Module}()
const _NLC_LOADED = Ref(false)
const _NLC_MODEL_FILES = Set{String}()

function _get_nlc()
    if !_NLC_LOADED[]
        NETLOGO_JL_DIR === nothing &&
            error("NetLogo.jl not found. Set NETLOGO_JL_DIR to the NetLogo.jl checkout to enable Java benchmark comparison.")
        include(joinpath(NETLOGO_JL_DIR, "eval", "NetLogoCompare.jl"))
        _NLC_REF[] = Main.NetLogoCompare
        _NLC_LOADED[] = true
    end
    return _NLC_REF[]
end

function bench_netlogo(name::String; n_runs::Int=3, seed::Int=42)
    NLC = _get_nlc()

    mpath = _find_wrapper_file(name)
    mpath === nothing && return nothing
    if mpath ∉ _NLC_MODEL_FILES
        Base.eval(NLC, :(include($mpath)))
        push!(_NLC_MODEL_FILES, mpath)
    end

    # Parse the model type name from the wrapper file (e.g., "struct FireModel <: ...")
    type_sym = nothing
    for line in eachline(mpath)
        m = match(r"struct\s+(\w+Model)\s+<:", line)
        if m !== nothing
            type_sym = Symbol(m.captures[1])
            break
        end
    end
    type_sym === nothing && return nothing

    model = try
        Base.invokelatest(getfield(NLC, type_sym))
    catch
        return nothing
    end

    nticks = Base.invokelatest(NLC.n_ticks, model)
    times = Float64[]
    for i in 1:n_runs
        t0 = time()
        try
            Base.invokelatest(NLC.run_java_trajectories, model, [seed + i])
        catch e
            @warn "NetLogo error for $name: $e"
            return nothing
        end
        push!(times, time() - t0)
    end
    return (median_time=median(times), min_time=minimum(times),
            mean_time=mean(times), n_ticks=nticks)
end

# ── Register all models ─────────────────────────────────────────────

# Original models
register_bench!("segregation"; run_fn=run_segregation, params_fn=(s,t)->SegregationParams(max_ticks=t, seed=s), n_ticks=200, description="Schelling segregation", category="social")
register_bench!("virus"; run_fn=run_virus, params_fn=(s,t)->VirusParams(max_ticks=t, seed=s), n_ticks=200, description="SIR epidemic on grid", category="epidemiology")
register_bench!("wolfsheep"; run_fn=run_wolfsheep, params_fn=(s,t)->WolfSheepParams(max_ticks=t, seed=s), n_ticks=200, description="Wolf-sheep predation", category="ecology")
register_bench!("ants"; run_fn=run_ants, params_fn=(s,t)->AntsParams(max_ticks=t, seed=s), n_ticks=200, description="Ant foraging", category="ecology")
register_bench!("fire"; run_fn=run_fire, params_fn=(s,t)->FireParams(max_ticks=t, seed=s), n_ticks=200, description="Forest fire spread", category="physics")
register_bench!("flocking"; run_fn=run_flocking, params_fn=(s,t)->FlockingParams(max_ticks=t, seed=s), n_ticks=200, description="Boids flocking", category="emergence")
register_bench!("ising"; run_fn=run_ising, params_fn=(s,t)->IsingParams(max_ticks=t, seed=s), n_ticks=200, description="Ising model", category="physics")
register_bench!("diffusion"; run_fn=run_diffusion, params_fn=(s,t)->DiffusionParams(max_ticks=t, seed=s), n_ticks=200, description="Heat diffusion", category="physics")
register_bench!("decay"; run_fn=run_decay, params_fn=(s,t)->DecayParams(max_ticks=t, seed=s), n_ticks=200, description="Radioactive decay", category="physics")

# Batch A: Emergence & ecology
register_bench!("termites"; run_fn=run_termites, params_fn=(s,t)->TMParams(max_ticks=t, seed=s), n_ticks=200, description="Chip collecting emergence", category="emergence")
register_bench!("slime"; run_fn=run_slime, params_fn=(s,t)->SLParams(max_ticks=t, seed=s), n_ticks=200, description="Slime mold chemotaxis", category="biology")
register_bench!("life"; run_fn=run_life, params_fn=(s,t)->LFParams(max_ticks=t, seed=s), n_ticks=200, description="Conway's Game of Life", category="cellular_automata")
register_bench!("bank_reserves"; run_fn=run_bank_reserves, params_fn=(s,t)->BRESParams(max_ticks=t, seed=s), n_ticks=200, description="Bank reserves economics", category="economics")
register_bench!("altruism"; run_fn=run_altruism, params_fn=(s,t)->ALTParams(max_ticks=t, seed=s), n_ticks=200, description="Evolution of altruism", category="evolution")
register_bench!("cooperation"; run_fn=run_cooperation, params_fn=(s,t)->COOPParams(max_ticks=t, seed=s), n_ticks=200, description="Evolution of cooperation", category="evolution")
register_bench!("giant_component"; run_fn=run_giant_component, params_fn=(s,t)->GCParams(max_ticks=t, seed=s), n_ticks=200, description="Network percolation", category="network")
register_bench!("rabbits_grass_weeds"; run_fn=run_rgw, params_fn=(s,t)->RGWParams(max_ticks=t, seed=s), n_ticks=200, description="Predator-prey ecosystem", category="ecology")

# Batch B: Traffic & social
register_bench!("heatbugs"; run_fn=run_heatbugs, params_fn=(s,t)->HBParams(max_ticks=t, seed=s), n_ticks=200, description="Thermal regulation", category="emergence")
register_bench!("shepherds"; run_fn=run_shepherds, params_fn=(s,t)->SHParams(max_ticks=t, seed=s), n_ticks=200, description="Herding behavior", category="emergence")
register_bench!("minority_game"; run_fn=run_minoritygame, params_fn=(s,t)->MGParams(max_ticks=t, seed=s), n_ticks=200, description="El Farol bar variant", category="game_theory")
register_bench!("percolation"; run_fn=run_percolation, params_fn=(s,t)->PERCParams(max_ticks=t, seed=s), n_ticks=200, description="Oil percolation", category="physics")
register_bench!("language_change"; run_fn=run_languagechange, params_fn=(s,t)->LCParams(max_ticks=t, seed=s), n_ticks=200, description="Linguistic evolution", category="social")
register_bench!("traffic_grid"; run_fn=run_trafficgrid, params_fn=(s,t)->TGParams(max_ticks=t, seed=s), n_ticks=200, description="Urban traffic grid", category="traffic")
register_bench!("traffic_2_lanes"; run_fn=run_traffic2lanes, params_fn=(s,t)->T2LParams(max_ticks=t, seed=s), n_ticks=200, description="Lane-changing traffic", category="traffic")
register_bench!("traffic_intersection"; run_fn=run_trafficintersection, params_fn=(s,t)->TIParams(max_ticks=t, seed=s), n_ticks=200, description="Intersection dynamics", category="traffic")

# Batch C: Networks & epidemiology
register_bench!("erosion"; run_fn=run_erosion, params_fn=(s,t)->ERParams(max_ticks=t, seed=s), n_ticks=200, description="Geological erosion", category="physics")
register_bench!("ca_1d_elementary"; run_fn=run_ca_1d_elementary, params_fn=(s,t)->CA1DParams(max_ticks=t, seed=s), n_ticks=49, description="Wolfram 1D CA", category="cellular_automata")
register_bench!("virus_on_network"; run_fn=run_virus_on_network, params_fn=(s,t)->VONParams(max_ticks=t, seed=s), n_ticks=200, description="SIR on network", category="epidemiology")
register_bench!("preferential_attachment"; run_fn=run_preferential_attachment, params_fn=(s,t)->PAParams(max_ticks=t, seed=s), n_ticks=200, description="Scale-free network", category="network")
register_bench!("small_worlds"; run_fn=run_small_worlds, params_fn=(s,t)->SWParams(max_ticks=t, seed=s), n_ticks=80, description="Watts-Strogatz", category="network")
register_bench!("rebellion"; run_fn=run_rebellion, params_fn=(s,t)->REBParams(max_ticks=t, seed=s), n_ticks=200, description="Epstein civil violence", category="social")
register_bench!("fireflies"; run_fn=run_fireflies, params_fn=(s,t)->FFParams(max_ticks=t, seed=s), n_ticks=200, description="Firefly synchronization", category="emergence")
register_bench!("aids"; run_fn=run_aids, params_fn=(s,t)->AIDSParams(max_ticks=t, seed=s), n_ticks=200, description="HIV transmission", category="epidemiology")

# Batch D: Game theory & CAs
register_bench!("pd_basic_evolutionary"; run_fn=run_pd_basic_evolutionary, params_fn=(s,t)->PDEParams(max_ticks=t, seed=s), n_ticks=200, description="Evolutionary PD", category="game_theory")
register_bench!("simple_genetic_algorithm"; run_fn=run_simple_genetic_algorithm, params_fn=(s,t)->SGAParams(max_ticks=t, seed=s), n_ticks=200, description="Genetic algorithm", category="optimization")
register_bench!("sugarscape_1_growback"; run_fn=run_sugarscape_1_growback, params_fn=(s,t)->S1GParams(max_ticks=t, seed=s), n_ticks=200, description="Sugarscape immediate growback", category="economics")
register_bench!("granovetter"; run_fn=run_granovetter, params_fn=(s,t)->GRANParams(max_ticks=t, seed=s), n_ticks=200, description="Threshold collective action", category="social")
register_bench!("logistic_growth"; run_fn=run_logistic_growth, params_fn=(s,t)->LGParams(max_ticks=t, seed=s), n_ticks=200, description="Logistic population growth", category="ecology")
register_bench!("voting"; run_fn=run_voting, params_fn=(s,t)->VOTParams(max_ticks=t, seed=s), n_ticks=200, description="Spatial voting", category="social")
register_bench!("public_good"; run_fn=run_public_good, params_fn=(s,t)->PGParams(max_ticks=t, seed=s), n_ticks=200, description="Public goods game", category="game_theory")
register_bench!("brians_brain"; run_fn=run_brians_brain, params_fn=(s,t)->BBParams(max_ticks=t, seed=s), n_ticks=200, description="Brian's Brain CA", category="cellular_automata")

# Batch E: Biology
register_bench!("tumor"; run_fn=run_tumor, params_fn=(s,t)->TumorParams(max_ticks=t, seed=s), n_ticks=50, description="Tumor growth", category="biology")
register_bench!("fungalbioremediation"; run_fn=run_fungalbioremediation, params_fn=(s,t)->FBRParams(max_ticks=t, seed=s), n_ticks=50, description="Fungal bioremediation", category="biology")

# Batch F: Cellular automata
register_bench!("infinitelife"; run_fn=run_infinitelife, params_fn=(s,t)->InfLifeParams(max_ticks=t, seed=s), n_ticks=20, description="Infinite Game of Life", category="cellular_automata")

# Batch G: Ecology
register_bench!("daisyworld"; run_fn=run_daisyworld, params_fn=(s,t)->DaisyworldParams(grid_size=15, max_ticks=t, seed=s), n_ticks=100, description="Daisyworld climate feedback", category="ecology")
register_bench!("gbt"; run_fn=run_gbt, params_fn=(s,t)->GBTParams(grid_width=50, grid_height=50, max_ticks=t, seed=s), n_ticks=200, description="Grass brush trees", category="ecology")
register_bench!("birthrates"; run_fn=run_birthrates, params_fn=(s,t)->BirthRatesParams(carrying_capacity=200, max_ticks=t, seed=s), n_ticks=50, description="Birth rate dynamics", category="ecology")
register_bench!("mimicry"; run_fn=run_mimicry, params_fn=(s,t)->MimicryParams(max_ticks=t, seed=s), n_ticks=200, description="Batesian mimicry", category="ecology")
register_bench!("croprotation"; run_fn=run_croprotation, params_fn=(s,t)->CRParams(max_ticks=t, seed=s), n_ticks=200, description="Crop rotation", category="ecology")
register_bench!("rhinopoaching"; run_fn=run_rhinopoaching, params_fn=(s,t)->RhinoParams(max_ticks=t, seed=s), n_ticks=200, description="Rhino poaching dynamics", category="ecology")
register_bench!("gishillclimber"; run_fn=run_gishillclimber, params_fn=(s,t)->GHCParams(max_ticks=t, seed=s), n_ticks=100, description="GIS hill climber", category="ecology")
register_bench!("csvpopulation"; run_fn=run_csvpopulation, params_fn=(s,t)->CsvPopParams(max_ticks=t, seed=s), n_ticks=100, description="CSV population ecology", category="ecology")
register_bench!("forestdewdney"; run_fn=run_forestdewdney, params_fn=(s,t)->FDParams(grid_width=10, grid_height=10, max_ticks=t, seed=s), n_ticks=100, description="Forest fire Dewdney", category="ecology")
register_bench!("csvnetworkforaging"; run_fn=run_csvnetworkforaging, params_fn=(s,t)->CNFParams(num_consumers=10, max_ticks=t, seed=s), n_ticks=50, description="CSV network foraging", category="ecology")

# Batch H: Economics
register_bench!("wealthdistribution"; run_fn=run_wealthdistribution, params_fn=(s,t)->WDParams(max_ticks=t, seed=s), n_ticks=50, description="Wealth distribution", category="economics")
register_bench!("paretolearn"; run_fn=run_paretolearn, params_fn=(s,t)->ParetoLearnParams(max_ticks=t, seed=s), n_ticks=200, description="Pareto learning", category="economics")
register_bench!("bullwhip"; run_fn=run_bullwhip, params_fn=(s,t)->BullwhipParams(num_ticks=t, seed=s), n_ticks=100, description="Bullwhip effect", category="economics")
register_bench!("tourism"; run_fn=run_tourism, params_fn=(s,t)->TourismParams(max_ticks=t, seed=s), n_ticks=50, description="Tourism dynamics", category="economics")
register_bench!("productsmarket"; run_fn=run_productsmarket, params_fn=(s,t)->PMktParams(max_ticks=t, seed=s), n_ticks=200, description="Products market", category="economics")
register_bench!("artificialeconomy"; run_fn=run_artificialeconomy, params_fn=(s,t)->AEconParams(max_ticks=t, seed=s), n_ticks=200, description="Artificial economy", category="economics")
register_bench!("sugarscapeculture"; run_fn=run_sugarscapeculture, params_fn=(s,t)->SCParams(initial_population=100, grid_width=25, grid_height=25, max_ticks=t, seed=s), n_ticks=50, description="Sugarscape culture", category="economics")
register_bench!("sugarscapesexual"; run_fn=run_sugarscapesexual, params_fn=(s,t)->SSParams(initial_population=50, grid_width=25, grid_height=25, max_ticks=t, seed=s), n_ticks=50, description="Sugarscape sexual reproduction", category="economics")
register_bench!("simplemarket"; run_fn=run_simplemarket, params_fn=(s,t)->SMktParams(max_ticks=t, seed=s), n_ticks=200, description="Simple market", category="economics")
register_bench!("simplemarketrandom"; run_fn=run_simplemarketrandom, params_fn=(s,t)->SMktRParams(max_ticks=t, seed=s), n_ticks=200, description="Simple market random", category="economics")
register_bench!("simplemarkettable"; run_fn=run_simplemarkettable, params_fn=(s,t)->SMktTParams(max_ticks=t, seed=s), n_ticks=200, description="Simple market table", category="economics")
register_bench!("babysittingcoop"; run_fn=run_babysittingcoop, params_fn=(s,t)->BSitParams(max_ticks=t, seed=s), n_ticks=100, description="Babysitting cooperative", category="economics")

# Batch I: Emergence
register_bench!("flockingnetwork"; run_fn=run_flockingnetwork, params_fn=(s,t)->FlockingNetworkParams(population=50, max_ticks=t, seed=s), n_ticks=50, description="Flocking on network", category="emergence")

# Batch J: Epidemiology
register_bench!("sir"; run_fn=run_sir, params_fn=(s,t)->SIRParams(num_people=100, initial_infected=3, max_ticks=t, seed=s), n_ticks=200, description="SIR compartmental model", category="epidemiology")
register_bench!("contagionsi"; run_fn=run_contagionsi, params_fn=(s,t)->ContagionSIParams(num_turtles=150, init_infected=3, max_ticks=t, seed=s), n_ticks=200, description="SI contagion", category="epidemiology")
register_bench!("contagionsir"; run_fn=run_contagionsir, params_fn=(s,t)->ContagionSIRParams(num_turtles=200, init_infected=3, max_ticks=t, seed=s), n_ticks=200, description="SIR contagion", category="epidemiology")
register_bench!("lassavirus"; run_fn=run_lassavirus, params_fn=(s,t)->LassaParams(max_ticks=t, seed=s), n_ticks=200, description="Lassa virus spread", category="epidemiology")
register_bench!("contagionnw"; run_fn=run_contagionnw, params_fn=(s,t)->ContagionNWParams(max_ticks=t, seed=s), n_ticks=200, description="Contagion on network", category="epidemiology")
register_bench!("minimalsis"; run_fn=run_minimalsis, params_fn=(s,t)->MinimalSISParams(max_ticks=t, seed=s), n_ticks=100, description="Minimal SIS model", category="epidemiology")

# Batch K: Evolution
register_bench!("ethnocentrism"; run_fn=run_ethnocentrism, params_fn=(s,t)->EthnocentrismParams(grid_size=20, max_ticks=t, seed=s), n_ticks=200, description="Ethnocentrism evolution", category="evolution")

# Batch L: Game theory
register_bench!("coordination"; run_fn=run_coordination, params_fn=(s,t)->CoordinationParams(grid_size=33, max_ticks=t, seed=s), n_ticks=200, description="Coordination game", category="game_theory")
register_bench!("coin"; run_fn=run_coin, params_fn=(s,t)->CoinParams(num_agents=63, max_ticks=t, seed=s), n_ticks=200, description="Coin flipping game", category="game_theory")
register_bench!("pdsimple"; run_fn=run_pdsimple, params_fn=(s,t)->PDSimpleParams(grid_size=33, max_ticks=t, seed=s), n_ticks=200, description="Simple prisoner's dilemma", category="game_theory")
register_bench!("ipd"; run_fn=run_ipd, params_fn=(s,t)->IPDParams(grid_size=50, max_ticks=t, seed=s), n_ticks=200, description="Iterated prisoner's dilemma", category="game_theory")
register_bench!("elfarol"; run_fn=run_elfarol, params_fn=(s,t)->ElFarolParams(max_ticks=t, seed=s), n_ticks=50, description="El Farol bar problem", category="game_theory")
register_bench!("coordination2groups"; run_fn=run_coordination2groups, params_fn=(s,t)->Coordination2GroupsParams(max_ticks=t, seed=s), n_ticks=200, description="Coordination two groups", category="game_theory")
register_bench!("rationalevolvingpd"; run_fn=run_rationalevolvingpd, params_fn=(s,t)->REPDParams(max_ticks=t, seed=s), n_ticks=100, description="Rational evolving PD", category="game_theory")

# Batch M: Network
register_bench!("slowspread"; run_fn=run_slowspread, params_fn=(s,t)->SSpreadParams(max_ticks=t, seed=s), n_ticks=200, description="Slow spread on network", category="network")
register_bench!("spreadinggroups"; run_fn=run_spreadinggroups, params_fn=(s,t)->SGroupParams(max_ticks=t, seed=s), n_ticks=100, description="Spreading in groups", category="network")
register_bench!("prefattachhomophily"; run_fn=run_prefattachhomophily, params_fn=(s,t)->PrefAttachHomophilyParams(max_ticks=t, seed=s), n_ticks=150, description="Preferential attachment + homophily", category="network")
register_bench!("diffusionnetwork"; run_fn=run_diffusionnetwork, params_fn=(s,t)->DiffusionNetworkParams(max_ticks=t, seed=s), n_ticks=20, description="Diffusion on network", category="network")
register_bench!("socialnetworkdiffusion"; run_fn=run_socialnetworkdiffusion, params_fn=(s,t)->SocialNetDiffParams(max_ticks=t, seed=s), n_ticks=20, description="Social network diffusion", category="network")

# Batch N: Optimization
register_bench!("antsystem"; run_fn=run_antsystem, params_fn=(s,t)->AntSystemParams(max_ticks=t, seed=s), n_ticks=100, description="Ant system optimization", category="optimization")

# Batch O: Physics
register_bench!("contactprocess"; run_fn=run_contactprocess, params_fn=(s,t)->ContactProcessParams(grid_width=25, grid_height=25, max_ticks=t, seed=s), n_ticks=100, description="Contact process", category="physics")
register_bench!("boiling"; run_fn=run_boiling, params_fn=(s,t)->BoilingParams(grid_width=81, grid_height=81, max_ticks=t, seed=s), n_ticks=200, description="Boiling simulation", category="physics")
register_bench!("mousetraps"; run_fn=run_mousetraps, params_fn=(s,t)->MousetrapParams(half_width=80, max_ticks=t, seed=s), n_ticks=150, description="Mousetraps chain reaction", category="physics")
register_bench!("rope"; run_fn=run_rope, params_fn=(s,t)->RopeParams(max_ticks=t), n_ticks=200, description="Rope physics", category="physics")
register_bench!("particles"; run_fn=run_particles, params_fn=(s,t)->ParticlesParams(num_particles=50, max_ticks=t, seed=s), n_ticks=200, description="Particle dynamics", category="physics")
register_bench!("firepercolation"; run_fn=run_firepercolation, params_fn=(s,t)->FirePercolationParams(p=0.6, grid_width=50, grid_height=50, max_ticks=t, seed=s), n_ticks=100, description="Fire percolation", category="physics")
register_bench!("sand"; run_fn=run_sand, params_fn=(s,t)->SandParams(grid_width=81, grid_height=81, max_ticks=t, seed=s), n_ticks=200, description="Sand pile model", category="physics")
register_bench!("soliddiffusion"; run_fn=run_soliddiffusion, params_fn=(s,t)->SolidDiffusionParams(grid_width=35, grid_height=35, max_ticks=t, seed=s), n_ticks=200, description="Solid state diffusion", category="physics")
register_bench!("crystallization"; run_fn=run_crystallization, params_fn=(s,t)->CrystallizationParams(metal_size=31, max_ticks=t, seed=s), n_ticks=200, description="Metal crystallization", category="physics")
register_bench!("thermostat"; run_fn=run_thermostat, params_fn=(s,t)->ThermostatParams(max_ticks=t, seed=s), n_ticks=200, description="Thermostat control", category="physics")
register_bench!("climatechange"; run_fn=run_climatechange, params_fn=(s,t)->ClimateChangeParams(max_ticks=t, seed=s), n_ticks=200, description="Climate change model", category="physics")
register_bench!("polymerdynamics"; run_fn=run_polymerdynamics, params_fn=(s,t)->PolymerDynamicsParams(max_ticks=t, seed=s), n_ticks=200, description="Polymer chain dynamics", category="physics")
register_bench!("firebenchmark"; run_fn=run_firebenchmark, params_fn=(s,t)->FBParams(max_ticks=t, seed=s), n_ticks=100, description="Fire benchmark variant", category="physics")
register_bench!("dlasimple"; run_fn=run_dlasimple, params_fn=(s,t)->DLAsParams(max_ticks=t, seed=s), n_ticks=200, description="Simple DLA", category="physics")
register_bench!("dla"; run_fn=run_dla, params_fn=(s,t)->DLAParams(num_particles=100, grid_width=33, grid_height=33, max_ticks=t, seed=s), n_ticks=100, description="Diffusion-limited aggregation", category="physics")

# Batch P: Social (part 1)
register_bench!("voter"; run_fn=run_voter, params_fn=(s,t)->VoterParams(grid_width=21, grid_height=21, max_ticks=t, seed=s), n_ticks=100, description="Voter model", category="social")
register_bench!("evolutionofnorms"; run_fn=run_evolutionofnorms, params_fn=(s,t)->NormParams(max_ticks=t, seed=s), n_ticks=100, description="Evolution of norms", category="social")
register_bench!("opinionbc"; run_fn=run_opinionbc, params_fn=(s,t)->OpinionBCParams(max_ticks=t, seed=s), n_ticks=200, description="Bounded confidence opinion", category="social")
register_bench!("axelrodcultural"; run_fn=run_axelrodcultural, params_fn=(s,t)->AxelrodParams(max_ticks=t, seed=s), n_ticks=200, description="Axelrod cultural model", category="social")
register_bench!("party"; run_fn=run_party, params_fn=(s,t)->PartyParams(max_ticks=t, seed=s), n_ticks=100, description="Party model", category="social")
register_bench!("bayesian"; run_fn=run_bayesian, params_fn=(s,t)->BayesianParams(max_ticks=t, seed=s), n_ticks=200, description="Bayesian updating", category="social")
register_bench!("unitcohesion"; run_fn=run_unitcohesion, params_fn=(s,t)->UnitCohesionParams(max_ticks=t, seed=s), n_ticks=200, description="Unit cohesion dynamics", category="social")
register_bench!("languageborders"; run_fn=run_languageborders, params_fn=(s,t)->LanguageBordersParams(max_ticks=t, seed=s), n_ticks=100, description="Language border formation", category="social")
register_bench!("beinggreen"; run_fn=run_beinggreen, params_fn=(s,t)->BeingGreenParams(max_ticks=t, seed=s), n_ticks=200, description="Being green adoption", category="social")
register_bench!("mailmen"; run_fn=run_mailmen, params_fn=(s,t)->MailmenParams(max_ticks=t, seed=s), n_ticks=200, description="Mailmen delivery", category="social")
register_bench!("civilizationgrowth"; run_fn=run_civilizationgrowth, params_fn=(s,t)->CivGrowthParams(max_ticks=t, seed=s), n_ticks=100, description="Civilization growth", category="social")
register_bench!("druguse"; run_fn=run_druguse, params_fn=(s,t)->DrugUseParams(max_ticks=t, seed=s), n_ticks=200, description="Drug use dynamics", category="social")
register_bench!("voronoivoter"; run_fn=run_voronoivoter, params_fn=(s,t)->VoronoiVoterParams(max_ticks=t, seed=s), n_ticks=100, description="Voronoi voter model", category="social")
register_bench!("marriage"; run_fn=run_marriage, params_fn=(s,t)->MarriageParams(max_ticks=t, seed=s), n_ticks=200, description="Marriage market", category="social")
register_bench!("teamassembly"; run_fn=run_teamassembly, params_fn=(s,t)->TeamAssemblyParams(max_ticks=t, seed=s), n_ticks=50, description="Team assembly", category="social")
register_bench!("dating"; run_fn=run_dating, params_fn=(s,t)->DatingParams(max_ticks=t, seed=s), n_ticks=200, description="Dating market", category="social")

# Batch Q: Social (part 2) — includes num_ticks models
register_bench!("cyber"; run_fn=run_cyber, params_fn=(s,t)->CyberParams(num_ticks=t, seed=s), n_ticks=200, description="Cyberspace opinion", category="social")
register_bench!("resilient"; run_fn=run_resilient, params_fn=(s,t)->ResilientParams(num_ticks=t, seed=s), n_ticks=200, description="Resilient team", category="social")
register_bench!("recruiting"; run_fn=run_recruiting, params_fn=(s,t)->RecParams(max_ticks=t, seed=s), n_ticks=100, description="Recruiting dynamics", category="social")
register_bench!("recruitingsupporters"; run_fn=run_recruitingsupporters, params_fn=(s,t)->RecSupParams(max_ticks=t, seed=s), n_ticks=50, description="Recruiting supporters", category="social")
register_bench!("minoritybelief"; run_fn=run_minoritybelief, params_fn=(s,t)->MBeliefParams(max_ticks=t, seed=s), n_ticks=200, description="Minority belief spread", category="social")
register_bench!("abtgc"; run_fn=run_abtgc, params_fn=(s,t)->ABTParams(max_ticks=t, seed=s), n_ticks=100, description="ABT group communication", category="social")
register_bench!("privacyopinion"; run_fn=run_privacyopinion, params_fn=(s,t)->PrvParams(max_ticks=t, seed=s), n_ticks=200, description="Privacy opinion dynamics", category="social")
register_bench!("modsocsegregation"; run_fn=run_modsocsegregation, params_fn=(s,t)->ModsocSegParams(max_ticks=t, seed=s), n_ticks=50, description="Modified social segregation", category="social")
register_bench!("socialinfluence"; run_fn=run_socialinfluence, params_fn=(s,t)->SInflParams(max_ticks=t, seed=s), n_ticks=200, description="Social influence model", category="social")
register_bench!("infodiffusion"; run_fn=run_infodiffusion, params_fn=(s,t)->InfoDiffParams(max_ticks=t, seed=s), n_ticks=200, description="Information diffusion", category="social")
register_bench!("schelling"; run_fn=run_schelling, params_fn=(s,t)->SchParams(max_ticks=t, seed=s), n_ticks=100, description="Schelling model variant", category="social")
register_bench!("fakenews"; run_fn=run_fakenews, params_fn=(s,t)->FNewsParams(max_ticks=t, seed=s), n_ticks=100, description="Fake news spread", category="social")
register_bench!("superdiffuser"; run_fn=run_superdiffuser, params_fn=(s,t)->SDiffParams(max_ticks=t, seed=s), n_ticks=200, description="Super-diffuser spread", category="social")
register_bench!("participatorydisinformation"; run_fn=run_participatorydisinformation, params_fn=(s,t)->PDisinfoParams(max_ticks=t, seed=s), n_ticks=200, description="Participatory disinformation", category="social")
register_bench!("culturaldiffusion"; run_fn=run_culturaldiffusion, params_fn=(s,t)->CulturalDiffusionParams(max_ticks=t, seed=s), n_ticks=200, description="Cultural diffusion", category="social")
register_bench!("druguseoverdose"; run_fn=run_druguseoverdose, params_fn=(s,t)->DrugUseOverdoseParams(max_ticks=t, seed=s), n_ticks=200, description="Drug use overdose", category="social")
register_bench!("spatialopinion"; run_fn=run_spatialopinion, params_fn=(s,t)->SOpnParams(max_ticks=t, seed=s), n_ticks=50, description="Spatial opinion dynamics", category="social")
register_bench!("spatialattitude"; run_fn=run_spatialattitude, params_fn=(s,t)->SAttParams(max_ticks=t, seed=s), n_ticks=50, description="Spatial attitude dynamics", category="social")
register_bench!("spreadingbots"; run_fn=run_spreadingbots, params_fn=(s,t)->SBotParams(max_ticks=t, seed=s), n_ticks=100, description="Spreading bots", category="social")
register_bench!("misinformationsbfc"; run_fn=run_misinformationsbfc, params_fn=(s,t)->MisSBFCParams(max_ticks=t, seed=s), n_ticks=200, description="Misinformation SBFC", category="social")
register_bench!("disinfobitstringnw"; run_fn=run_disinfobitstringnw, params_fn=(s,t)->DisBitParams(max_ticks=t, seed=s), n_ticks=200, description="Disinfo bitstring network", category="social")
register_bench!("participatorydisinfo"; run_fn=run_participatorydisinfo, params_fn=(s,t)->PDisParams(max_ticks=t, seed=s), n_ticks=200, description="Participatory disinfo variant", category="social")
register_bench!("rumormill"; run_fn=run_rumormill, params_fn=(s,t)->RMParams(grid_width=21, grid_height=21, seed_one=true, max_ticks=t, seed=s), n_ticks=100, description="Rumor mill spread", category="social")
register_bench!("cqin"; run_fn=run_cqin, params_fn=(s,t)->CQINParams(number_of_nodes=30, max_ticks=t, seed=s), n_ticks=20, description="CQIN social network", category="social")
register_bench!("competitionlearning"; run_fn=run_competitionlearning, params_fn=(s,t)->CLParams(max_ticks=t, seed=s), n_ticks=200, description="Competition learning", category="social")
register_bench!("leonarditechadoption"; run_fn=run_leonarditechadoption, params_fn=(s,t)->LTechParams(max_ticks=t, seed=s), n_ticks=100, description="Leonardi tech adoption", category="social")
register_bench!("wisdomcrowd"; run_fn=run_wisdomcrowd, params_fn=(s,t)->WCParams(max_ticks=t, seed=s), n_ticks=50, description="Wisdom of crowds", category="social")
register_bench!("recruitingmovement"; run_fn=run_recruitingmovement, params_fn=(s,t)->RecMovParams(max_ticks=t, seed=s), n_ticks=100, description="Recruiting movement", category="social")

# Batch R: Traffic
register_bench!("trafficbasic"; run_fn=run_trafficbasic, params_fn=(s,t)->TBParams(number_of_cars=15, road_length=31, max_ticks=t, seed=s), n_ticks=100, description="Basic traffic model", category="traffic")

# Batch S: Other
register_bench!("blackbox"; run_fn=run_blackbox, params_fn=(s,t)->BBoxParams(max_ticks=t, seed=s), n_ticks=200, description="Black box optimization", category="other")

# ── Pretty printing ─────────────────────────────────────────────────

function format_time(t::Float64)
    if t < 1e-3
        return "$(round(t*1e6, digits=1))μs"
    elseif t < 1.0
        return "$(round(t*1e3, digits=1))ms"
    else
        return "$(round(t, digits=2))s"
    end
end

function format_bytes(b)
    b = Float64(b)
    if b < 1024
        return "$(Int(b))B"
    elseif b < 1024^2
        return "$(round(b/1024, digits=1))KB"
    elseif b < 1024^3
        return "$(round(b/1024^2, digits=1))MB"
    else
        return "$(round(b/1024^3, digits=2))GB"
    end
end

# ── Main runner ─────────────────────────────────────────────────────

function run_benchmarks(; models::Vector{String}=String[], compare_netlogo::Bool=false,
                         n_warmup::Int=1, n_runs::Int=5)
    if isempty(models)
        models = sort(collect(keys(BENCH_REGISTRY)))
    end

    println("\n╔══════════════════════════════════════════════════════════════╗")
    println("║          ArkModelZoo.jl Performance Benchmarks             ║")
    println("╚══════════════════════════════════════════════════════════════╝")
    println("  Models: $(length(models))")
    println("  Ark runs: $n_runs (+ $n_warmup warmup)")
    compare_netlogo && println("  NetLogo comparison: enabled")
    println()

    results = []

    # Header
    if compare_netlogo
        println("| Model | Category | Ticks | Ark (median) | Ark (alloc) | NetLogo | Speedup |")
        println("|-------|----------|-------|-------------|-------------|---------|---------|")
    else
        println("| Model | Category | Ticks | Median | Min | Mean±Std | Allocations |")
        println("|-------|----------|-------|--------|-----|----------|-------------|")
    end

    # Models known to hang in Java NetLogo (too slow / infinite loops)
    skip_netlogo = Set(["minority_game", "small_worlds", "rebellion", "productsmarket",
                        "participatorydisinformation", "participatorydisinfo", "rumormill",
                        "trafficbasic"])

    for name in models
        haskey(BENCH_REGISTRY, name) || continue
        reg = BENCH_REGISTRY[name]

        # Ark benchmark
        ark = try
            bench_ark(name; n_warmup=n_warmup, n_runs=n_runs)
        catch e
            @warn "Ark error for $name: $e"
            nothing
        end
        ark === nothing && continue

        if compare_netlogo
            # NetLogo benchmark (skip known-hanging models)
            nl = if name ∈ skip_netlogo
                nothing
            else
                try
                    bench_netlogo(name; n_runs=min(n_runs, 3))
                catch e
                    @warn "NetLogo error for $name: $e"
                    nothing
                end
            end

            speedup = nl !== nothing ? nl.median_time / ark.median_time : NaN
            nl_str = nl !== nothing ? format_time(nl.median_time) : "N/A"
            sp_str = isnan(speedup) ? "N/A" : "$(round(speedup, digits=1))×"

            println("| $name | $(reg.category) | $(ark.n_ticks) | $(format_time(ark.median_time)) | $(format_bytes(ark.median_alloc)) | $nl_str | $sp_str |")
            flush(stdout)
            push!(results, (name=name, category=reg.category, ticks=ark.n_ticks,
                           ark_time=ark.median_time, ark_alloc=ark.median_alloc,
                           nl_time=nl !== nothing ? nl.median_time : NaN,
                           speedup=speedup))
        else
            println("| $name | $(reg.category) | $(ark.n_ticks) | $(format_time(ark.median_time)) | $(format_time(ark.min_time)) | $(format_time(ark.mean_time))±$(format_time(ark.std_time)) | $(format_bytes(ark.median_alloc)) |")
            push!(results, (name=name, category=reg.category, ticks=ark.n_ticks,
                           ark_time=ark.median_time, ark_alloc=ark.median_alloc))
        end
    end

    # Summary
    println()
    ark_times = [r.ark_time for r in results]
    println("════════════════════════════════════════════")
    println("  Total models benchmarked: $(length(results))")
    println("  Ark median total: $(format_time(sum(ark_times)))")
    println("  Ark fastest: $(results[argmin(ark_times)].name) ($(format_time(minimum(ark_times))))")
    println("  Ark slowest: $(results[argmax(ark_times)].name) ($(format_time(maximum(ark_times))))")

    if compare_netlogo
        speedups = [r.speedup for r in results if !isnan(r.speedup)]
        if !isempty(speedups)
            println("  Median speedup vs NetLogo: $(round(median(speedups), digits=1))×")
            println("  Min speedup: $(round(minimum(speedups), digits=1))×")
            println("  Max speedup: $(round(maximum(speedups), digits=1))×")
        end
    end
    println("════════════════════════════════════════════")

    # Category summary
    println("\n  By category:")
    cats = unique([r.category for r in results])
    for cat in sort(cats)
        cat_results = filter(r -> r.category == cat, results)
        cat_time = median([r.ark_time for r in cat_results])
        println("    $cat ($(length(cat_results)) models): median $(format_time(cat_time))")
    end

    return results
end

# ── CLI ──────────────────────────────────────────────────────────────

if abspath(PROGRAM_FILE) == @__FILE__
    compare_nl = "--netlogo" in ARGS
    model_args = filter(a -> !startswith(a, "--"), ARGS)
    models = if isempty(model_args)
        String[]
    else
        String.(split(model_args[1], ","))
    end
    run_benchmarks(; models=models, compare_netlogo=compare_nl)
end
