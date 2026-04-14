cd("/Users/username/Projects/ecs/ArkModelZoo.jl")
using Test
using Pkg; Pkg.activate(".")
using ArkModelZoo, Ark

@testset "Batch D" begin

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
        @test trajectory[end][1] >= trajectory[1][1]
        println("  Simple GA: best_fitness=$(trajectory[end][1]), mean=$(round(trajectory[end][2], digits=1))")
    end

    @testset "Sugarscape 1 Growback" begin
        params = S1GParams(initial_population=100, grid_width=50, grid_height=50, max_ticks=50, seed=42)
        scheduler, trajectory = run_sugarscape_1_growback(params=params)
        @test length(trajectory) > 1
        @test trajectory[1][1] == 100.0
        println("  Sugarscape 1: final pop=$(Int(trajectory[end][1])), mean_sugar=$(round(trajectory[end][2], digits=1))")
    end

    @testset "Granovetter" begin
        params = GRANParams(number_of_agents=20, max_ticks=30, seed=42)
        scheduler, trajectory = run_granovetter(params=params)
        @test length(trajectory) > 1
        @test trajectory[end][1] >= trajectory[1][1]
        println("  Granovetter: final %rioting=$(round(trajectory[end][1], digits=1))")
    end

    @testset "Logistic Growth" begin
        params = LGParams(initial_stock=0.1, max_ticks=500, seed=42)
        scheduler, trajectory = run_logistic_growth(params=params)
        @test length(trajectory) > 1
        @test trajectory[1][1] ≈ 0.1
        @test trajectory[end][1] > 0.9
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

end

println("\n✅ All Batch D tests passed!")
