# ============================================================
# Batch D Integration Instructions
# Add these to src/ArkModelZoo.jl and test/runtests.jl
# ============================================================

# ---- INCLUDES (add to src/ArkModelZoo.jl) ----
# Place these after the last model include block:

# --- PD Basic Evolutionary ---
# include("pd_basic_evolutionary/components.jl")
# include("pd_basic_evolutionary/resources.jl")
# include("pd_basic_evolutionary/parameters.jl")
# include("pd_basic_evolutionary/systems.jl")
# include("pd_basic_evolutionary/model.jl")

# --- Simple Genetic Algorithm ---
# include("simple_genetic_algorithm/components.jl")
# include("simple_genetic_algorithm/resources.jl")
# include("simple_genetic_algorithm/parameters.jl")
# include("simple_genetic_algorithm/systems.jl")
# include("simple_genetic_algorithm/model.jl")

# --- Sugarscape 1 Immediate Growback ---
# include("sugarscape_1_growback/components.jl")
# include("sugarscape_1_growback/resources.jl")
# include("sugarscape_1_growback/parameters.jl")
# include("sugarscape_1_growback/systems.jl")
# include("sugarscape_1_growback/model.jl")

# --- Granovetter ---
# include("granovetter/components.jl")
# include("granovetter/resources.jl")
# include("granovetter/parameters.jl")
# include("granovetter/systems.jl")
# include("granovetter/model.jl")

# --- Logistic Growth ---
# include("logistic_growth/components.jl")
# include("logistic_growth/resources.jl")
# include("logistic_growth/parameters.jl")
# include("logistic_growth/systems.jl")
# include("logistic_growth/model.jl")

# --- Voting ---
# include("voting/components.jl")
# include("voting/resources.jl")
# include("voting/parameters.jl")
# include("voting/systems.jl")
# include("voting/model.jl")

# --- Public Good ---
# include("public_good/components.jl")
# include("public_good/resources.jl")
# include("public_good/parameters.jl")
# include("public_good/systems.jl")
# include("public_good/model.jl")

# --- Brian's Brain ---
# include("brians_brain/components.jl")
# include("brians_brain/resources.jl")
# include("brians_brain/parameters.jl")
# include("brians_brain/systems.jl")
# include("brians_brain/model.jl")

# ---- EXPORTS (add to the export block in src/ArkModelZoo.jl) ----

# export PDEParams, PDEGrid, PDEStats,
#        pde_headers, pde_values, run_pd_basic_evolutionary
# export SGAParams, SGABits, SGAStats,
#        sga_headers, sga_values, run_simple_genetic_algorithm
# export S1GParams, S1GAgent, S1GGrid, S1GStats,
#        s1g_headers, s1g_values, run_sugarscape_1_growback
# export GRANParams, GRANAgent, GRANNetwork, GRANStats,
#        gran_headers, gran_values, run_granovetter
# export LGParams, LGState,
#        lg_headers, lg_values, run_logistic_growth
# export VOTParams, VOTGrid, VOTStats,
#        vot_headers, vot_values, run_voting
# export PGParams, PGStudent, PGStats,
#        pg_headers, pg_values, run_public_good
# export BBParams, BBGrid, BBStats,
#        bb_headers, bb_values, run_brians_brain

# ---- TEST BLOCKS (add to test/runtests.jl) ----

#=
    @testset "PD Basic Evolutionary" begin
        params = PDEParams(grid_width=21, grid_height=21, max_ticks=50, seed=42)
        scheduler, trajectory = run_pd_basic_evolutionary(params=params)
        @test length(trajectory) > 1
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= 1
        @test trajectory[1][1] + trajectory[1][2] == params.grid_width * params.grid_height
        println("  PD Basic Evolutionary: $(tick.tick) ticks, cooperators=$(Int(trajectory[end][1]))")
    end

    @testset "Simple Genetic Algorithm" begin
        params = SGAParams(population_size=50, chromosome_length=20, max_ticks=200, seed=42)
        scheduler, trajectory = run_simple_genetic_algorithm(params=params)
        @test length(trajectory) > 1
        @test trajectory[end][1] >= trajectory[1][1]  # best fitness should improve
        println("  Simple GA: best_fitness=$(trajectory[end][1]), mean=$(round(trajectory[end][2], digits=1))")
    end

    @testset "Sugarscape 1 Growback" begin
        params = S1GParams(initial_population=100, grid_width=50, grid_height=50, max_ticks=50, seed=42)
        scheduler, trajectory = run_sugarscape_1_growback(params=params)
        @test length(trajectory) > 1
        @test trajectory[1][1] == 100.0  # initial population
        println("  Sugarscape 1: final pop=$(Int(trajectory[end][1])), mean_sugar=$(round(trajectory[end][2], digits=1))")
    end

    @testset "Granovetter" begin
        params = GRANParams(number_of_agents=20, max_ticks=30, seed=42)
        scheduler, trajectory = run_granovetter(params=params)
        @test length(trajectory) > 1
        @test trajectory[end][1] >= trajectory[1][1]  # rioting can only increase
        println("  Granovetter: final %rioting=$(round(trajectory[end][1], digits=1))")
    end

    @testset "Logistic Growth" begin
        params = LGParams(initial_stock=0.1, max_ticks=500, seed=42)
        scheduler, trajectory = run_logistic_growth(params=params)
        @test length(trajectory) > 1
        @test trajectory[1][1] ≈ 0.1
        @test trajectory[end][1] > 0.9  # should approach 1.0
        println("  Logistic Growth: final stock=$(round(trajectory[end][1], digits=4))")
    end

    @testset "Voting" begin
        params = VOTParams(grid_width=31, grid_height=31, max_ticks=50, seed=42)
        scheduler, trajectory = run_voting(params=params)
        @test length(trajectory) > 1
        @test trajectory[1][1] + trajectory[1][2] == params.grid_width * params.grid_height
        println("  Voting: final blue=$(Int(trajectory[end][1])), green=$(Int(trajectory[end][2]))")
    end

    @testset "Public Good" begin
        params = PGParams(num_agents=10, max_ticks=20, seed=42)
        scheduler, trajectory = run_public_good(params=params)
        @test length(trajectory) > 1
        @test trajectory[1][1] == params.initial_money
        println("  Public Good: final mean_money=$(round(trajectory[end][1], digits=2))")
    end

    @testset "Brian's Brain" begin
        params = BBParams(grid_width=21, grid_height=21, max_ticks=50, seed=42)
        scheduler, trajectory = run_brians_brain(params=params)
        @test length(trajectory) > 1
        total_cells = params.grid_width * params.grid_height
        @test trajectory[1][1] + trajectory[1][2] + trajectory[1][3] == total_cells
        println("  Brian's Brain: final firing=$(Int(trajectory[end][1])), refractory=$(Int(trajectory[end][2]))")
    end
=#
