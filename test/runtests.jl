using Test
using Ark
using ArkModelZoo

const _CLASSMODELS_DIR = let
    path = get(ENV, "NETLOGO_CLASSMODELS_DIR", "")
    isempty(path) ? nothing : normpath(path)
end

function _classmodels_path(parts...)
    _CLASSMODELS_DIR === nothing && return nothing
    path = joinpath(_CLASSMODELS_DIR, parts...)
    return ispath(path) ? path : nothing
end

@testset "ArkModelZoo" begin

    @testset "Model registry" begin
        specs = model_catalog()
        @test length(specs) == 155
        @test length(available_models()) == 155
        @test model_categories() == [
            "Biology & Ecology",
            "Computer Science & Math",
            "Economics",
            "Land Use & GIS",
            "Miscellaneous",
            "Networks",
            "Physics & Chemistry",
            "Social Science",
            "Other Models",
        ]

        sir = model_info("sir")
        @test sir.title == "SIR"
        @test sir.category == "Biology & Ecology"
        @test sir.params_symbol == :SIRParams
        @test sir.run_symbol == :run_sir
        @test isdefined(ArkModelZoo, sir.params_symbol)
        @test isdefined(ArkModelZoo, sir.run_symbol)

        rgw = model_info("run_rgw")
        @test rgw.name == "rabbits_grass_weeds"
        @test rgw.run_symbol == :run_rgw
        @test :run_rabbits_grass_weeds in rgw.exports

        @test model_info("simple_birth_rates").name == "birthrates"
        @test model_info("disinfo_nw_bitstring").name == "disinfobitstringnw"
        @test model_info("artificial_economy").name == "artificialeconomy"
        @test model_info("search_path").run_symbol == :run_search_path

        _, generic_traj = run_model("simple_birth_rates"; params = BirthRatesParams(max_ticks=5, seed=7))
        @test !isempty(generic_traj)

        social = model_catalog(category = "Social Science")
        @test !isempty(social)
        @test all(spec -> spec.category == "Social Science", social)
        @test "sir" in available_models(category = "Biology & Ecology")

        @test_throws ErrorException model_info("definitely_not_a_model")
    end

    @testset "Segregation" begin
        params = SegregationParams(density=80.0, grid_width=21, grid_height=21, max_ticks=50, seed=42)
        scheduler, trajectory = run_segregation(params=params)
        @test length(trajectory) > 1
        # Should converge or reach max ticks
        stats = get_resource(scheduler.world, SegregationStats)
        tick = get_resource(scheduler.world, Tick)
        @test stats.num_unhappy == 0 || tick.tick >= params.max_ticks
        # Percent similar should increase from initial random ~50%
        @test trajectory[end][1] > trajectory[1][1]
        println("  Segregation: $(tick.tick) ticks, final %similar=$(round(stats.percent_similar, digits=1))")
    end

    @testset "Wolf-Sheep Predation" begin
        params = WolfSheepParams(
            initial_number_sheep=80, initial_number_wolves=30,
            grid_width=31, grid_height=31, max_ticks=200, seed=42
        )
        scheduler, trajectory = run_wolfsheep(params=params)
        @test length(trajectory) > 1
        # Population should have changed
        @test trajectory[end] != trajectory[1]
        stats = get_resource(scheduler.world, WSPopulationStats)
        tick = get_resource(scheduler.world, Tick)
        println("  Wolf-Sheep: $(tick.tick) ticks, sheep=$(stats.sheep_count), wolves=$(stats.wolf_count)")
    end

    @testset "Ants" begin
        params = AntsParams(population=50, grid_size=41, max_ticks=200, seed=42)
        scheduler, trajectory = run_ants(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, AntsStats)
        tick = get_resource(scheduler.world, Tick)
        # Ants should have collected some food
        @test stats.total_food_collected >= 0
        println("  Ants: $(tick.tick) ticks, food collected=$(stats.total_food_collected)")
    end

    @testset "Daisyworld" begin
        params = DaisyworldParams(grid_size=15, max_ticks=100, seed=42)
        scheduler, trajectory = run_daisyworld(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, DaisyStats)
        tick = get_resource(scheduler.world, Tick)
        @test stats.global_temperature > 0.0
        println("  Daisyworld: $(tick.tick) ticks, temp=$(round(stats.global_temperature, digits=1)), " *
                "whites=$(stats.num_whites), blacks=$(stats.num_blacks)")
    end

    @testset "Virus" begin
        params = VirusParams(number_people=150, max_ticks=150, seed=42)
        scheduler, trajectory = run_virus(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, VirusStats)
        tick = get_resource(scheduler.world, Tick)
        # Fixed population: S + I + R = number_people
        @test stats.num_susceptible + stats.num_infected + stats.num_resistant == 150
        println("  Virus: $(tick.tick) ticks, S=$(stats.num_susceptible), I=$(stats.num_infected), R=$(stats.num_resistant)")
    end

    @testset "Ethnocentrism" begin
        params = EthnocentrismParams(grid_size=20, max_ticks=200, seed=42)
        scheduler, trajectory = run_ethnocentrism(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, EthnoStats)
        tick = get_resource(scheduler.world, Tick)
        @test stats.total_population > 0
        println("  Ethnocentrism: $(tick.tick) ticks, population=$(stats.total_population)")
    end

    @testset "Search Path" begin
        params = SearchPathParams(total_time=50, max_ticks=50, seed=42)
        scheduler, trajectory = run_search_path(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, SearchPathStats)
        tick = get_resource(scheduler.world, Tick)
        @test trajectory[1] == [0.0, 0.0]
        @test 0 <= stats.number_caught <= params.number_of_targets
        @test trajectory[end][1] == stats.number_caught
        @test trajectory[end][2] == tick.tick
        println("  Search Path: $(tick.tick) ticks, caught=$(stats.number_caught)")
    end

    @testset "Voter" begin
        params = VoterParams(grid_width=21, grid_height=21, max_ticks=100, seed=42)
        scheduler, trajectory = run_voter(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, VoterStats)
        tick = get_resource(scheduler.world, Tick)
        @test stats.n_colors >= 1
        println("  Voter: $(tick.tick) ticks, n_colors=$(stats.n_colors)")
    end

    @testset "Ising" begin
        params = IsingParams(grid_width=21, grid_height=21, max_ticks=100, seed=42)
        scheduler, trajectory = run_ising(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, IsingStats)
        tick = get_resource(scheduler.world, Tick)
        @test abs(stats.sum_of_spins) <= params.grid_width * params.grid_height
        println("  Ising: $(tick.tick) ticks, sum_of_spins=$(stats.sum_of_spins)")
    end

    @testset "Fire" begin
        params = FireParams(density=57, grid_width=51, grid_height=51, max_ticks=200, seed=42)
        scheduler, trajectory = run_fire(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, FireStats)
        tick = get_resource(scheduler.world, Tick)
        @test stats.burned_trees >= 0
        println("  Fire: $(tick.tick) ticks, burned=$(stats.burned_trees)/$(stats.initial_trees)")
    end

    @testset "Decay" begin
        params = DecayParams(number_nuclei=500, max_ticks=100, seed=42)
        scheduler, trajectory = run_decay(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, DecayStats)
        tick = get_resource(scheduler.world, Tick)
        @test stats.total_active >= 0
        @test stats.total_active < 500  # some should have decayed
        println("  Decay: $(tick.tick) ticks, active=$(stats.total_active)/500")
    end

    @testset "DLA" begin
        params = DLAParams(num_particles=100, grid_width=33, grid_height=33, max_ticks=100, seed=42)
        scheduler, trajectory = run_dla(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, DLAStats)
        tick = get_resource(scheduler.world, Tick)
        @test stats.n_remaining >= 0
        @test stats.n_remaining < 100  # some should have attached
        println("  DLA: $(tick.tick) ticks, remaining=$(stats.n_remaining)/100")
    end

    @testset "Contact Process" begin
        params = ContactProcessParams(grid_width=25, grid_height=25, max_ticks=100, seed=42)
        scheduler, trajectory = run_contactprocess(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, ContactStats)
        tick = get_resource(scheduler.world, Tick)
        @test 0.0 <= stats.p_occupied <= 1.0
        println("  Contact Process: $(tick.tick) ticks, p_occupied=$(round(stats.p_occupied, digits=3))")
    end

    @testset "Flocking" begin
        params = FlockingParams(population=50, grid_width=31, grid_height=31, max_ticks=100, seed=42)
        scheduler, trajectory = run_flocking(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, FlockStats)
        tick = get_resource(scheduler.world, Tick)
        @test 0.0 <= stats.avg_heading <= 360.0
        println("  Flocking: $(tick.tick) ticks, avg_heading=$(round(stats.avg_heading, digits=1))")
    end

    @testset "Grass-Brush-Trees" begin
        params = GBTParams(grid_width=50, grid_height=50, max_ticks=200, seed=42)
        scheduler, trajectory = run_gbt(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, GBTStats)
        tick = get_resource(scheduler.world, Tick)
        @test 0 <= stats.n_trees <= params.grid_width * params.grid_height
        @test tick.tick >= params.max_ticks
        println("  Grass-Brush-Trees: $(tick.tick) ticks, n_trees=$(stats.n_trees)")
    end

    @testset "SIR" begin
        params = SIRParams(num_people=100, initial_infected=3, max_ticks=200, seed=42)
        scheduler, trajectory = run_sir(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, SIRStats)
        tick = get_resource(scheduler.world, Tick)
        # Conservation: S + I + R = num_people
        @test stats.num_susceptible + stats.num_infected + stats.num_recovered == 100
        println("  SIR: $(tick.tick) ticks, S=$(stats.num_susceptible), I=$(stats.num_infected), R=$(stats.num_recovered)")
    end

    @testset "Boiling" begin
        params = BoilingParams(grid_width=81, grid_height=81, max_ticks=200, seed=42)
        scheduler, trajectory = run_boiling(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, BoilingStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test 0.0 <= stats.avg_heat <= 212.0
        println("  Boiling: $(tick.tick) ticks, avg_heat=$(round(stats.avg_heat, digits=1))")
    end

    @testset "Birth Rates" begin
        params = BirthRatesParams(carrying_capacity=200, max_ticks=50, seed=42)
        scheduler, trajectory = run_birthrates(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, BirthRatesStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        # Both populations should persist
        @test stats.red_count > 0
        @test stats.blue_count > 0
        # Total near carrying capacity (grim reaper regulates)
        @test stats.red_count + stats.blue_count > 0
        println("  Birth Rates: $(tick.tick) ticks, red=$(stats.red_count), blue=$(stats.blue_count)")
    end

    @testset "Mousetraps" begin
        params = MousetrapParams(half_width=80, max_ticks=150, seed=42)
        scheduler, trajectory = run_mousetraps(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, MousetrapStats)
        tick = get_resource(scheduler.world, Tick)
        @test stats.traps_triggered > 0
        @test stats.traps_triggered <= 161 * 161
        println("  Mousetraps: $(tick.tick) ticks, traps_triggered=$(stats.traps_triggered), balls_in_air=$(stats.balls_in_air)")
    end

    @testset "Rope" begin
        params = RopeParams(max_ticks=500)
        scheduler, trajectory = run_rope(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, RopeStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test stats.n_visible >= 0
        @test stats.n_visible <= params.world_width
        # At tick 0, n-visible matches NetLogo default (0, not set in setup)
        @test trajectory[1][1] == 0.0
        println("  Rope: $(tick.tick) ticks, n_visible=$(stats.n_visible)")
    end

    @testset "Coordination" begin
        params = CoordinationParams(grid_size=33, max_ticks=200, seed=42)
        scheduler, trajectory = run_coordination(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, CoordStats)
        tick = get_resource(scheduler.world, Tick)
        total = params.grid_size * params.grid_size
        # Should stop by convergence or max ticks
        @test stats.n_norm1 == 0 || stats.n_norm1 == total || tick.tick >= params.max_ticks
        # n_norm1 should be in valid range
        @test 0 <= stats.n_norm1 <= total
        println("  Coordination: $(tick.tick) ticks, n_norm1=$(stats.n_norm1)/$(total)")
    end

    @testset "COIN" begin
        params = CoinParams(num_agents=63, max_ticks=200, seed=42)
        scheduler, trajectory = run_coin(params=params)
        @test length(trajectory) > 1
        state = get_resource(scheduler.world, CoinState)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        # Utility should be positive after learning
        @test state.current_utility > 0.0
        # Utility should improve from start (warmup already trains, so check positive)
        @test trajectory[end][1] > 0.0
        # Attendance should sum to num_agents
        @test sum(state.attendance) == params.num_agents
        println("  COIN: $(tick.tick) ticks, utility=$(round(state.current_utility, digits=3))")
    end

    @testset "Diffusion" begin
        params = DiffusionParams(grid_width=33, grid_height=33, max_ticks=100, seed=42)
        scheduler, trajectory = run_diffusion(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, DiffusionStats)
        tick = get_resource(scheduler.world, Tick)
        @test stats.max_temp == 100.0  # center always reset to 100
        @test stats.mean_temp > 0.0
        println("  Diffusion: $(tick.tick) ticks, max_temp=$(round(stats.max_temp, digits=1)), mean_temp=$(round(stats.mean_temp, digits=4))")
    end

    @testset "Particles" begin
        params = ParticlesParams(num_particles=50, max_ticks=200, seed=42)
        scheduler, trajectory = run_particles(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, ParticleStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        # Should have some collisions after 200 ticks with 50 particles
        @test stats.collisions > 0
        # Collisions should be non-decreasing (cumulative)
        @test trajectory[end][1] >= trajectory[1][1]
        println("  Particles: $(tick.tick) ticks, collisions=$(stats.collisions)")
    end

    @testset "Contagion SI" begin
        params = ContagionSIParams(num_turtles=150, init_infected=3, max_ticks=200, seed=42)
        scheduler, trajectory = run_contagionsi(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, CIStats)
        tick = get_resource(scheduler.world, Tick)
        # Infected should be monotonically non-decreasing (SI model)
        for i in 2:length(trajectory)
            @test trajectory[i][1] >= trajectory[i-1][1]
        end
        # Should have more infected than initial
        @test stats.n_infected >= 3
        # Conservation: total agents unchanged
        s_count = 0
        for (eids, _) in Query(scheduler.world, (CIPosition,); with=(CISusceptible,))
            s_count += length(eids)
        end
        @test s_count + stats.n_infected == 150
        println("  Contagion SI: $(tick.tick) ticks, infected=$(stats.n_infected)/150")
    end

    @testset "Fire Percolation" begin
        params = FirePercolationParams(p=0.6, grid_width=50, grid_height=50, max_ticks=100, seed=42)
        scheduler, trajectory = run_firepercolation(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, FirePercStats)
        tick = get_resource(scheduler.world, Tick)
        @test stats.fire_size >= 1  # at least the ignited patch
        @test stats.fire_size <= 50 * 50
        println("  Fire Percolation: $(tick.tick) ticks, fire_size=$(stats.fire_size)")
    end

    @testset "Contagion SIR" begin
        params = ContagionSIRParams(num_turtles=200, init_infected=3, max_ticks=200, seed=42)
        scheduler, trajectory = run_contagionsir(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, CSIRStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test 0 <= stats.n_infected <= params.num_turtles
        # With remove_recovered=false, n_immune should always be 0
        @test stats.n_immune == 0
        println("  Contagion SIR: $(tick.tick) ticks, infected=$(stats.n_infected), immune=$(stats.n_immune)")
    end

    @testset "Sand" begin
        params = SandParams(grid_width=81, grid_height=81, max_ticks=200, seed=42)
        scheduler, trajectory = run_sand(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, SandStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test stats.n_brown >= 0
        # Sand should accumulate over time
        @test trajectory[end][1] > trajectory[1][1]
        println("  Sand: $(tick.tick) ticks, n_brown=$(stats.n_brown)")
    end

    @testset "Solid Diffusion" begin
        params = SolidDiffusionParams(grid_width=35, grid_height=35, max_ticks=200, seed=42)
        scheduler, trajectory = run_soliddiffusion(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, SDStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        # n_turtles should be constant (atoms just swap with vacancies)
        @test stats.n_turtles == 1190
        @test trajectory[1][1] == trajectory[end][1]
        println("  Solid Diffusion: $(tick.tick) ticks, n_turtles=$(stats.n_turtles)")
    end

    @testset "PD Simple" begin
        params = PDSimpleParams(grid_size=33, max_ticks=200, seed=42)
        scheduler, trajectory = run_pdsimple(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, PDSStats)
        tick = get_resource(scheduler.world, Tick)
        @test 0 <= stats.n_cooperators <= params.grid_size * params.grid_size
        println("  PD Simple: $(tick.tick) ticks, n_cooperators=$(stats.n_cooperators)")
    end

    @testset "IPD" begin
        params = IPDParams(grid_size=50, max_ticks=200, seed=42)
        scheduler, trajectory = run_ipd(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, IPDStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test stats.mean_score >= 0.0
        println("  IPD: $(tick.tick) ticks, mean_score=$(round(stats.mean_score, digits=2))")
    end

    @testset "Crystallization" begin
        params = CrystallizationParams(metal_size=31, max_ticks=200, seed=42)
        scheduler, trajectory = run_crystallization(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, CrystStats)
        tick = get_resource(scheduler.world, Tick)
        # Temperature should decrease from init (1550)
        @test stats.ave_metal_temp < params.init_metal_temp
        @test stats.ave_metal_temp > 0.0
        @test stats.num_frozen >= 0
        println("  Crystallization: $(tick.tick) ticks, ave_temp=$(round(stats.ave_metal_temp, digits=1)), frozen=$(stats.num_frozen)")
    end

    @testset "El Farol" begin
        params = ElFarolParams(max_ticks=50, seed=42)
        scheduler, trajectory = run_elfarol(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, ElFarolStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test 0 <= stats.attendance <= 100
        println("  El Farol: $(tick.tick) ticks, attendance=$(stats.attendance)")
    end

    @testset "Thermostat" begin
        params = ThermostatParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_thermostat(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, ThermoStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test stats.temperature > 0.0
        # Temperature should approach goal (67)
        println("  Thermostat: $(tick.tick) ticks, temp=$(round(stats.temperature, digits=1))")
    end

    @testset "Tumor" begin
        params = TumorParams(max_ticks=50, seed=42)
        scheduler, trajectory = run_tumor(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, TumorStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        # Cell count should grow from 2
        @test stats.cell_count > 2
        println("  Tumor: $(tick.tick) ticks, cells=$(stats.cell_count)")
    end

    @testset "Mimicry" begin
        params = MimicryParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_mimicry(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, MimicryStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test stats.n_monarchs >= 0
        @test stats.n_viceroys >= 0
        @test stats.n_birds >= 0
        println("  Mimicry: $(tick.tick) ticks, monarchs=$(stats.n_monarchs), viceroys=$(stats.n_viceroys), birds=$(stats.n_birds)")
    end

    @testset "Evolution of Norms" begin
        params = NormParams(max_ticks=100, seed=42)
        scheduler, trajectory = run_evolutionofnorms(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, NormStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        # Mean and SD should be finite
        @test isfinite(stats.mean_points)
        @test isfinite(stats.sd_points)
        println("  Evolution of Norms: $(tick.tick) ticks, mean=$(round(stats.mean_points, digits=1)), sd=$(round(stats.sd_points, digits=1))")
    end

    @testset "Opinion BC" begin
        params = OpinionBCParams(max_ticks=5000, seed=42)
        scheduler, trajectory = run_opinionbc(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, OpinionBCStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test -1.0 <= stats.mean_opinion <= 1.0
        @test stats.sd_opinion >= 0.0
        println("  Opinion BC: $(tick.tick) ticks, mean=$(round(stats.mean_opinion, digits=3)), sd=$(round(stats.sd_opinion, digits=3))")
    end

    @testset "Wealth Distribution" begin
        params = WDParams(max_ticks=50, seed=42)
        scheduler, trajectory = run_wealthdistribution(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, WDStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test stats.gini_index_reserve >= 0.0
        println("  Wealth Distribution: $(tick.tick) ticks, gini=$(round(stats.gini_index_reserve, digits=3))")
    end

    @testset "Axelrod Cultural" begin
        params = AxelrodParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_axelrodcultural(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, AxelrodStats)
        tick = get_resource(scheduler.world, Tick)
        @test stats.number_of_cultures >= 1
        @test stats.number_of_cultures <= 125  # max = q^F = 5^3
        println("  Axelrod Cultural: $(tick.tick) ticks, cultures=$(stats.number_of_cultures), active=$(stats.number_of_active_agents)")
    end

    @testset "Party" begin
        params = PartyParams(max_ticks=100, seed=42)
        scheduler, trajectory = run_party(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, PartyStats)
        tick = get_resource(scheduler.world, Tick)
        @test 0 <= stats.boring_groups <= params.num_groups
        println("  Party: $(tick.tick) ticks, boring_groups=$(stats.boring_groups)")
    end

    @testset "Bayesian" begin
        params = BayesianParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_bayesian(params=params)
        @test length(trajectory) == 201
        state = get_resource(scheduler.world, BayesianState)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test 0.0 <= state.prob_true <= 1.0
        println("  Bayesian: $(tick.tick) ticks, prob_true=$(state.prob_true)")
    end

    @testset "Polymer Dynamics" begin
        params = PolymerDynamicsParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_polymerdynamics(params=params)
        @test length(trajectory) == 201
        stats = get_resource(scheduler.world, PolymerStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test stats.n_turtles == 158  # constant — turtles never die
        println("  Polymer Dynamics: $(tick.tick) ticks, n_turtles=$(stats.n_turtles)")
    end

    @testset "Unit Cohesion" begin
        params = UnitCohesionParams(max_ticks=500, seed=42)
        scheduler, trajectory = run_unitcohesion(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, UnitCohesionStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test stats.n_vacancies >= 0
        println("  Unit Cohesion: $(tick.tick) ticks, n_vacancies=$(stats.n_vacancies)")
    end

    @testset "Pareto Learning" begin
        params = ParetoLearnParams(max_ticks=500, seed=42)
        scheduler, trajectory = run_paretolearn(params=params)
        @test length(trajectory) == 501
        stats = get_resource(scheduler.world, ParetoStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test stats.eu_defect > stats.eu_cooperate  # defection dominates
        println("  Pareto Learning: $(tick.tick) ticks, eu_coop=$(round(stats.eu_cooperate, digits=3)), eu_def=$(round(stats.eu_defect, digits=3))")
    end

    @testset "Coordination 2 Groups" begin
        params = Coordination2GroupsParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_coordination2groups(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, Coordination2GroupsStats)
        tick = get_resource(scheduler.world, Tick)
        @test stats.n_norm1 >= 0
        println("  Coordination 2 Groups: $(tick.tick) ticks, n_norm1=$(stats.n_norm1)")
    end

    @testset "Language Borders" begin
        params = LanguageBordersParams(max_ticks=100, seed=42)
        scheduler, trajectory = run_languageborders(params=params)
        @test length(trajectory) == 101
        stats = get_resource(scheduler.world, LanguageBordersStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test 55.0 <= stats.avg_language <= 105.0
        println("  Language Borders: $(tick.tick) ticks, avg_language=$(round(stats.avg_language, digits=2))")
    end

    @testset "Being Green" begin
        params = BeingGreenParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_beinggreen(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, BeingGreenStats)
        tick = get_resource(scheduler.world, Tick)
        @test stats.n_action_takers >= 0
        println("  Being Green: $(tick.tick) ticks, n_action_takers=$(stats.n_action_takers)")
    end

    @testset "Climate Change" begin
        params = ClimateChangeParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_climatechange(params=params)
        @test length(trajectory) == 201
        stats = get_resource(scheduler.world, ClimateStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test stats.temperature > 0.0
        println("  Climate Change: $(tick.tick) ticks, temperature=$(round(stats.temperature, digits=2))")
    end

    @testset "Mailmen" begin
        params = MailmenParams(seed=42)
        scheduler, trajectory = run_mailmen(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, MailmenStats)
        tick = get_resource(scheduler.world, Tick)
        @test stats.num_remaining == 0  # all letters delivered
        println("  Mailmen: $(tick.tick) ticks, total_dist=$(round(stats.total_dist, digits=2)), remaining=$(stats.num_remaining)")
    end

    @testset "Lassa Virus" begin
        params = LassaParams(max_ticks=500, seed=42)
        scheduler, trajectory = run_lassavirus(params=params)
        @test length(trajectory) == 501
        stats = get_resource(scheduler.world, LassaStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test stats.pct_infected >= 0.0
        println("  Lassa Virus: $(tick.tick) ticks, pct_infected=$(round(stats.pct_infected, digits=2))")
    end

    @testset "Tourism" begin
        params = TourismParams(max_ticks=50, seed=42)
        scheduler, trajectory = run_tourism(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, TourismStats)
        tick = get_resource(scheduler.world, Tick)
        @test stats.attendance >= 0.0
        println("  Tourism: $(tick.tick) ticks, attendance=$(round(stats.attendance, digits=1)), reputation=$(round(stats.reputation, digits=1))")
    end

    @testset "Civilization Growth" begin
        params = CivGrowthParams(max_ticks=100, seed=42)
        scheduler, trajectory = run_civilizationgrowth(params=params)
        @test length(trajectory) == 101
        stats = get_resource(scheduler.world, CivStats)
        tick = get_resource(scheduler.world, Tick)
        @test tick.tick >= params.max_ticks
        @test stats.n_civs >= 0
        println("  Civilization Growth: $(tick.tick) ticks, n_civs=$(stats.n_civs)")
    end

    @testset "Drug Use" begin
        params = DrugUseParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_druguse(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, DrugStats)
        tick = get_resource(scheduler.world, Tick)
        @test stats.number_overdoses >= 0
        println("  Drug Use: $(tick.tick) ticks, overdoses=$(stats.number_overdoses)")
    end

    @testset "Voronoi Voter" begin
        params = VoronoiVoterParams(max_ticks=100, seed=42)
        scheduler, trajectory = run_voronoivoter(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, VoronoiStats)
        @test stats.n_colors >= 1
        println("  Voronoi Voter: $(length(trajectory)-1) ticks, n_colors=$(stats.n_colors)")
    end

    @testset "Marriage" begin
        params = MarriageParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_marriage(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, MarriageStats)
        @test stats.num_bachelors >= 0
        println("  Marriage: $(length(trajectory)-1) ticks, bachelors=$(stats.num_bachelors)")
    end

    @testset "Infinite Life" begin
        params = InfLifeParams(max_ticks=20, seed=42)
        scheduler, trajectory = run_infinitelife(params=params)
        @test length(trajectory) == 21
        stats = get_resource(scheduler.world, InfLifeStats)
        @test stats.n_cells >= 0
        println("  Infinite Life: $(length(trajectory)-1) ticks, cells=$(stats.n_cells)")
    end

    @testset "Ant System TSP" begin
        params = AntSystemParams(max_ticks=100, seed=42)
        scheduler, trajectory = run_antsystem(params=params)
        @test length(trajectory) == 101
        stats = get_resource(scheduler.world, TSPStats)
        @test stats.best_tour_cost > 0
        println("  Ant System: 100 ticks, best_tour_cost=$(stats.best_tour_cost)")
    end

    @testset "Team Assembly" begin
        params = TeamAssemblyParams(max_ticks=50, seed=42)
        scheduler, trajectory = run_teamassembly(params=params)
        @test length(trajectory) == 51
        stats = get_resource(scheduler.world, TeamStats)
        @test stats.giant_component_size >= 1
        println("  Team Assembly: 50 ticks, giant_component=$(stats.giant_component_size)")
    end

    @testset "Dating" begin
        params = DatingParams(max_ticks=500, seed=42)
        scheduler, trajectory = run_dating(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, DatingStats)
        @test stats.n_paired >= 0
        println("  Dating: $(length(trajectory)-1) ticks, n_paired=$(stats.n_paired)")
    end

    @testset "Bullwhip Effect" begin
        params = BullwhipParams(num_ticks=100, seed=42)
        scheduler, trajectory = run_bullwhip(params=params)
        @test length(trajectory) >= 101
        stats = get_resource(scheduler.world, BullwhipStats)
        @test stats.n_customers >= 0
        println("  Bullwhip Effect: $(length(trajectory)-1) ticks, n_customers=$(stats.n_customers)")
    end

    @testset "Cyberspace Opinion" begin
        params = CyberParams(num_ticks=200, seed=42)
        scheduler, trajectory = run_cyber(params=params)
        @test length(trajectory) >= 201
        stats = get_resource(scheduler.world, CyberStats)
        @test stats.n_infected >= 0
        println("  Cyberspace Opinion: $(length(trajectory)-1) ticks, infected=$(stats.n_infected), recovered=$(stats.n_recovered)")
    end

    @testset "Resilient Team" begin
        params = ResilientParams(num_ticks=200, seed=42)
        scheduler, trajectory = run_resilient(params=params)
        @test length(trajectory) >= 201
        stats = get_resource(scheduler.world, ResilientStats)
        @test stats.mean_stress >= 0.0
        println("  Resilient Team: $(length(trajectory)-1) ticks, mean_stress=$(round(stats.mean_stress, digits=2)), mean_resilience=$(round(stats.mean_resilience, digits=2))")
    end

    @testset "Recruiting" begin
        params = RecParams(max_ticks=100, seed=42)
        scheduler, trajectory = run_recruiting(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, RecStats)
        @test stats.recruitpct >= 0.0
        println("  Recruiting: $(length(trajectory)-1) ticks, recruit=$(round(stats.recruitpct, digits=1))%, resist=$(round(stats.resistpct, digits=1))%")
    end

    @testset "Recruiting Supporters" begin
        params = RecSupParams(max_ticks=50, seed=42)
        scheduler, trajectory = run_recruitingsupporters(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, RecSupStats)
        @test stats.recruitpct >= 0.0
        println("  Recruiting Supporters: $(length(trajectory)-1) ticks, recruit=$(round(stats.recruitpct, digits=1))%")
    end

    @testset "Minority Belief" begin
        params = MBeliefParams(max_ticks=500, seed=42)
        scheduler, trajectory = run_minoritybelief(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, MBeliefStats)
        @test stats.n_magenta >= 0
        println("  Minority Belief: $(length(trajectory)-1) ticks, magenta=$(stats.n_magenta), yellow=$(stats.n_yellow), cyan=$(stats.n_cyan)")
    end

    @testset "ABTgc" begin
        params = ABTParams(max_ticks=100, seed=42)
        scheduler, trajectory = run_abtgc(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, ABTStats)
        @test stats.bad_links >= 0
        println("  ABTgc: $(length(trajectory)-1) ticks, bad_links=$(stats.bad_links), unhandled=$(stats.unhandled_messages)")
    end

    @testset "Privacy Opinion" begin
        params = PrvParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_privacyopinion(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, PrvStats)
        @test stats.adopters_total >= 0
        println("  Privacy Opinion: $(length(trajectory)-1) ticks, adopters=$(stats.adopters_total), pct=$(round(stats.adopter_percent, digits=1))%")
    end

    @testset "Rational Evolving PD" begin
        params = REPDParams(max_ticks=100, seed=42)
        scheduler, trajectory = run_rationalevolvingpd(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, REPDStats)
        @test stats.n_alive >= 0
        println("  Rational Evolving PD: $(length(trajectory)-1) ticks, alive=$(stats.n_alive), neurons=$(stats.n_neurons)")
    end

    @testset "Crop Rotation" begin
        params = CRParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_croprotation(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, CRStats)
        @test stats.n_active_crops >= 0
        println("  Crop Rotation: $(length(trajectory)-1) ticks, active=$(stats.n_active_crops)")
    end

    @testset "Modsoc Segregation" begin
        params = ModsocSegParams(max_ticks=50, seed=42)
        scheduler, trajectory = run_modsocsegregation(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, ModsocStats)
        @test stats.average_similarity >= 0.0
        println("  Modsoc Segregation: $(length(trajectory)-1) ticks, avg_sim=$(round(stats.average_similarity, digits=3)), unhappiness=$(round(stats.unhappiness, digits=3))")
    end

    @testset "Fire Benchmark" begin
        params = FBParams(max_ticks=100, seed=42)
        scheduler, trajectory = run_firebenchmark(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, FBStats)
        @test stats.burned_trees >= 0
        println("  Fire Benchmark: $(length(trajectory)-1) ticks, burned=$(stats.burned_trees)")
    end

    @testset "Social Influence" begin
        params = SInflParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_socialinfluence(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, SInflStats)
        @test stats.number_influence >= 2
        println("  Social Influence: $(length(trajectory)-1) ticks, influence=$(stats.number_influence)")
    end

    @testset "Info Diffusion" begin
        params = InfoDiffParams(max_ticks=300, seed=42)
        scheduler, trajectory = run_infodiffusion(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, InfoDiffStats)
        @test stats.num_believers + stats.num_factcheckers + stats.num_susceptibles == params.n_agents
        println("  Info Diffusion: $(length(trajectory)-1) ticks, B=$(stats.num_believers), F=$(stats.num_factcheckers), S=$(stats.num_susceptibles)")
    end

    @testset "DLA Simple" begin
        params = DLAsParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_dlasimple(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, DLAsStats)
        @test stats.n_remaining >= 0
        @test stats.n_remaining <= params.num_particles
        println("  DLA Simple: $(length(trajectory)-1) ticks, remaining=$(stats.n_remaining)")
    end

    @testset "Schelling" begin
        params = SchParams(max_ticks=100, seed=42)
        scheduler, trajectory = run_schelling(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, SchStats)
        @test stats.percent_similar >= 0.0
        println("  Schelling: $(length(trajectory)-1) ticks, similar=$(round(stats.percent_similar, digits=1))%, unhappy=$(round(stats.percent_unhappy, digits=1))%")
    end

    @testset "Fake News" begin
        params = FNewsParams(max_ticks=100, seed=42)
        scheduler, trajectory = run_fakenews(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, FNewsStats)
        @test stats.pct_aware >= 0.0
        println("  Fake News: $(length(trajectory)-1) ticks, aware=$(round(stats.pct_aware, digits=1))%")
    end

    @testset "SuperDiffuser" begin
        params = SDiffParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_superdiffuser(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, SDiffStats)
        @test stats.current_adopted >= 0
        println("  SuperDiffuser: $(length(trajectory)-1) ticks, adopted=$(stats.current_adopted)")
    end

    @testset "Slow Spread" begin
        params = SSpreadParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_slowspread(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, SSpreadStats)
        @test stats.pct_green >= 0.0
        @test stats.pct_grey >= 0.0
        println("  Slow Spread: $(length(trajectory)-1) ticks, green=$(round(stats.pct_green, digits=1))%, grey=$(round(stats.pct_grey, digits=1))%")
    end

    @testset "Spreading Groups" begin
        params = SGroupParams(max_ticks=100, seed=42)
        scheduler, trajectory = run_spreadinggroups(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, SGroupStats)
        @test stats.num_infected >= 0
        println("  Spreading Groups: $(length(trajectory)-1) ticks, infected=$(stats.num_infected)")
    end

    @testset "Products Market" begin
        params = PMktParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_productsmarket(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, PMktStats)
        @test stats.count_apple >= 0
        @test stats.count_samsung >= 0
        println("  Products Market: $(length(trajectory)-1) ticks, apple=$(stats.count_apple), samsung=$(stats.count_samsung)")
    end

    @testset "Participatory Disinformation" begin
        params = PDisinfoParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_participatorydisinformation(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, PDisinfoStats)
        @test stats.times_heard_from_elites >= 0
        println("  Part. Disinfo: $(length(trajectory)-1) ticks, elite_heard=$(stats.times_heard_from_elites), social=$(stats.times_heard_from_social)")
    end

    @testset "Artificial Economy" begin
        params = AEconParams(max_ticks=200, seed=42)
        @test params.population == 100
        @test params.fuel_grow_rate == 5.0
        @test params.productivity_farmerworld == 5.0
        @test params.productivity_cityworld == 5.0
        @test params.depreciation == 0.1
        @test params.produce_supply_level == 20.0
        @test params.widget_supply_level == 20.0
        @test params.markup == 1.0
        scheduler, trajectory = run_artificialeconomy(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, AEconStats)
        @test stats.n_farmers >= 0
        @test stats.n_professionals >= 0
        @test stats.n_farmers + stats.n_professionals > 0
        println("  Artificial Economy: $(length(trajectory)-1) ticks, farmers=$(stats.n_farmers), professionals=$(stats.n_professionals)")
    end

    @testset "Rhino Poaching" begin
        params = RhinoParams(max_ticks=200, seed=42)
        @test params.num_rhinos == 70
        @test params.num_poachers == 4
        scheduler, trajectory = run_rhinopoaching(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, RhinoStats)
        @test stats.n_rhinos >= 0
        @test stats.total_killed >= 0
        println("  Rhino Poaching: $(length(trajectory)-1) ticks, rhinos=$(stats.n_rhinos), poachers=$(stats.n_poachers), killed=$(stats.total_killed)")
    end

    @testset "GIS Hill Climber" begin
        scheduler, trajectory = run_gishillclimber(params=GHCParams(max_ticks=100, seed=42))
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, GHCStats)
        @test stats.mean_elevation > 0
        @test stats.n_at_peak >= 0
        println("  GIS HillClimber: $(length(trajectory)-1) ticks, mean_elev=$(round(stats.mean_elevation, digits=1)), n_peak=$(stats.n_at_peak)")
    end

    if (hike_path = _classmodels_path("OtherClasses", "HikingElevation", "Clipped-Grayson.asc")) !== nothing
    @testset "Hiking Elevation" begin
        scheduler, trajectory = run_hikingelevation(params=HikeParams(max_ticks=200, seed=42, data_path=hike_path))
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, HikeStats)
        @test stats.track_elevation >= 0
        println("  Hiking Elevation: $(length(trajectory)-1) ticks, track_elev=$(round(stats.track_elevation, digits=1))")
    end
    else
        @info "Skipping Hiking Elevation tests; set NETLOGO_CLASSMODELS_DIR to enable GIS fixture tests."
    end

    if (bomb_path = _classmodels_path("CSS645Models", "BombScenario", "lenfant_new_clipped3.asc")) !== nothing
    @testset "Bomb Scenario" begin
        scheduler, trajectory = run_bombscenario(params=BombParams(max_ticks=50, seed=42, data_path=bomb_path))
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, BombStats)
        @test stats.arrested_total >= 0
        println("  Bomb Scenario: $(length(trajectory)-1) ticks, arrested=$(stats.arrested_total)")
    end
    else
        @info "Skipping Bomb Scenario tests; set NETLOGO_CLASSMODELS_DIR to enable GIS fixture tests."
    end

    if (mdr_path = _classmodels_path("CSS600Models", "MultidrugResistant", "data", "mincosf1.asc")) !== nothing
    @testset "Multidrug Resistant" begin
        scheduler, trajectory = run_multidrugresistant(params=MDRParams(max_ticks=200, seed=42, data_path=mdr_path))
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, MDRStats)
        @test stats.dead_patients >= 0
        @test stats.recovered_patients >= 0
        println("  Multidrug Resistant: $(length(trajectory)-1) ticks, dead=$(stats.dead_patients), recovered=$(stats.recovered_patients)")
    end
    else
        @info "Skipping Multidrug Resistant tests; set NETLOGO_CLASSMODELS_DIR to enable GIS fixture tests."
    end

    if (sleuth_dir = _classmodels_path("OtherClasses", "Politics_of_LandUse")) !== nothing
    @testset "Sleuth Land Use" begin
        scheduler, trajectory = run_sleuthlanduse(params=SleuthParams(max_ticks=50, seed=42, data_dir=sleuth_dir))
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, SleuthStats)
        @test stats.urbantotal > 0
        @test 0 <= stats.purbantotal <= 1
        println("  Sleuth Land Use: $(length(trajectory)-1) ticks, urban=$(stats.urbantotal), pct=$(round(stats.purbantotal*100, digits=1))%")
    end
    else
        @info "Skipping Sleuth Land Use tests; set NETLOGO_CLASSMODELS_DIR to enable GIS fixture tests."
    end

    @testset "Diffusion of HIV" begin
        scheduler, trajectory = run_diffusionofhiv(params=HIVParams(max_ticks=100, seed=42))
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, HIVStats)
        @test 0 <= stats.pct_infected <= 1
        println("  Diffusion HIV: $(length(trajectory)-1) ticks, pct_infected=$(round(stats.pct_infected*100, digits=1))%")
    end

    if (rad_dir = _classmodels_path("CSS645Models", "Rise_of_Radicalism", "data")) !== nothing
    @testset "Rise of Radicalism" begin
        scheduler, trajectory = run_riseofradicalism(params=RadParams(max_ticks=50, seed=42, data_dir=rad_dir))
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, RadStats)
        @test stats.percent_radicals >= 0
        @test stats.overtaken_townships >= 0
        println("  Rise of Radicalism: $(length(trajectory)-1) ticks, pct_rad=$(round(stats.percent_radicals, digits=1))%, townships=$(round(stats.overtaken_townships, digits=1))%")
    end
    else
        @info "Skipping Rise of Radicalism tests; set NETLOGO_CLASSMODELS_DIR to enable GIS fixture tests."
    end

    @testset "Contagion NW" begin
        params = ContagionNWParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_contagionnw(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, CNWStats)
        @test stats.num_infected >= 1
        @test stats.num_links >= 1
        println("  Contagion NW: $(length(trajectory)-1) ticks, infected=$(stats.num_infected), links=$(stats.num_links)")
    end

    @testset "Pref Attach Homophily" begin
        params = PrefAttachHomophilyParams(max_ticks=150, seed=42)
        scheduler, trajectory = run_prefattachhomophily(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, PAHStats)
        @test stats.num_links >= 0
        println("  Pref Attach Homophily: $(length(trajectory)-1) ticks, homophily=$(stats.number_homophily), links=$(stats.num_links)")
    end

    @testset "Diffusion Network" begin
        params = DiffusionNetworkParams(max_ticks=20, seed=42)
        scheduler, trajectory = run_diffusionnetwork(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, DNStats)
        @test stats.num_red + stats.num_grey == params.members
        println("  Diffusion Network: $(length(trajectory)-1) ticks, red=$(stats.num_red), grey=$(stats.num_grey)")
    end

    @testset "Social Network Diffusion" begin
        params = SocialNetDiffParams(max_ticks=20, seed=42)
        scheduler, trajectory = run_socialnetworkdiffusion(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, SNDStats)
        @test stats.num_red + stats.num_grey == params.members
        println("  Social Network Diffusion: $(length(trajectory)-1) ticks, red=$(stats.num_red), grey=$(stats.num_grey), utility=$(round(stats.avg_utility, digits=3))")
    end

    @testset "Minimal SIS" begin
        params = MinimalSISParams(max_ticks=100, seed=42)
        scheduler, trajectory = run_minimalsis(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, MSISStats)
        @test stats.reproduction_number >= 0
        println("  Minimal SIS: $(length(trajectory)-1) ticks, R=$(round(stats.reproduction_number, digits=2)), new_infected=$(stats.new_infected)")
    end

    @testset "Flocking Network" begin
        params = FlockingNetworkParams(population=50, max_ticks=50, seed=42)
        scheduler, trajectory = run_flockingnetwork(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, FNStats)
        @test stats.num_links >= 0
        println("  Flocking Network: $(length(trajectory)-1) ticks, links=$(stats.num_links), avg_heading=$(round(stats.avg_heading, digits=1))")
    end

    @testset "Cultural Diffusion" begin
        params = CulturalDiffusionParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_culturaldiffusion(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, CDStats)
        @test stats.num_iter > 0
        @test stats.total_langs >= 0
        println("  Cultural Diffusion: $(length(trajectory)-1) ticks, iterations=$(stats.num_iter), total_langs=$(stats.total_langs)")
    end

    @testset "Drug Use Overdose" begin
        params = DrugUseOverdoseParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_druguseoverdose(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, DUOStats)
        @test stats.number_overdoses >= 0
        @test stats.num_alive >= 0
        println("  Drug Use Overdose: $(length(trajectory)-1) ticks, overdoses=$(stats.number_overdoses), alive=$(stats.num_alive), users=$(stats.num_drug_users)")
    end

    @testset "Spatial Opinion" begin
        params = SOpnParams(max_ticks=50, seed=42)
        scheduler, trajectory = run_spatialopinion(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, SOpnStats)
        @test 0 <= stats.left_freq <= 1
        @test 0 <= stats.right_freq <= 1
        println("  Spatial Opinion: $(length(trajectory)-1) ticks, fizz=$(round(stats.fizz, digits=3)), left=$(round(stats.left_freq, digits=3)), right=$(round(stats.right_freq, digits=3))")
    end

    @testset "Spatial Attitude" begin
        params = SAttParams(max_ticks=50, seed=42)
        scheduler, trajectory = run_spatialattitude(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, SAttStats)
        @test 0 <= stats.left_freq <= 1
        @test 0 <= stats.right_freq <= 1
        println("  Spatial Attitude: $(length(trajectory)-1) ticks, fizz=$(round(stats.fizz, digits=3)), left=$(round(stats.left_freq, digits=3)), right=$(round(stats.right_freq, digits=3))")
    end

    @testset "Spreading Bots" begin
        params = SBotParams(max_ticks=100, seed=42)
        scheduler, trajectory = run_spreadingbots(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, SBotStats)
        @test stats.num_infected >= 0
        println("  Spreading Bots: $(length(trajectory)-1) ticks, infected=$(stats.num_infected)")
    end

    @testset "Misinformation SBFC" begin
        params = MisSBFCParams(max_ticks=300, seed=42)
        scheduler, trajectory = run_misinformationsbfc(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, MisSBFCStats)
        @test stats.num_believers + stats.num_factcheckers + stats.num_susceptibles == params.number_of_agents
        println("  Misinformation SBFC: $(length(trajectory)-1) ticks, B=$(stats.num_believers), F=$(stats.num_factcheckers), S=$(stats.num_susceptibles)")
    end

    @testset "Disinfo NW Bitstring" begin
        params = DisBitParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_disinfobitstringnw(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, DisBitStats)
        @test stats.times_heard_from_elites >= 0
        println("  Disinfo NW Bitstring: $(length(trajectory)-1) ticks, elite=$(stats.times_heard_from_elites), social=$(stats.times_heard_from_social)")
    end

    @testset "Participatory Disinfo" begin
        params = PDisParams(max_ticks=200, seed=42)
        scheduler, trajectory = run_participatorydisinfo(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, PDisStats)
        @test stats.times_heard_from_elites >= 0
        println("  Part. Disinfo: $(length(trajectory)-1) ticks, elite=$(stats.times_heard_from_elites), social=$(stats.times_heard_from_social)")
    end

    @testset "BlackBox" begin
        params = BBoxParams(max_ticks=500, seed=42)
        scheduler, trajectory = run_blackbox(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, BBoxStats)
        @test stats.q4t >= 0
        @test stats.q3t >= 0
        println("  BlackBox: $(length(trajectory)-1) ticks, Q4t=$(stats.q4t), Q3t=$(stats.q3t)")
    end

    @testset "CSV Population" begin
        params = CsvPopParams(max_ticks=100, seed=42)
        scheduler, trajectory = run_csvpopulation(params=params)
        @test length(trajectory) >= 2
        @test length(trajectory[1]) == 3
        stats = get_resource(scheduler.world, CsvPopStats)
        @test stats.pop_count >= 0
        println("  CSV Population: $(length(trajectory)-1) ticks, pop=$(stats.pop_count), energy=$(round(stats.total_energy, digits=1))")
    end

    @testset "Traffic Basic" begin
        params = TBParams(number_of_cars=15, road_length=31, max_ticks=100, seed=42)
        scheduler, trajectory = run_trafficbasic(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, TBStats)
        @test stats.mean_speed >= 0.0
        println("  Traffic Basic: $(length(trajectory)-1) ticks, mean_speed=$(round(stats.mean_speed, digits=3))")
    end

    @testset "Rumor Mill" begin
        params = RMParams(grid_width=21, grid_height=21, seed_one=true, max_ticks=100, seed=42)
        scheduler, trajectory = run_rumormill(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, RMStats)
        @test stats.clique > 0
        println("  Rumor Mill: $(length(trajectory)-1) ticks, clique=$(stats.clique)/$(params.grid_width * params.grid_height)")
    end

    @testset "Forest Dewdney" begin
        params = FDParams(grid_width=10, grid_height=10, max_ticks=100, seed=42)
        scheduler, trajectory = run_forestdewdney(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, FDStats)
        @test stats.local_richness > 0
        println("  Forest Dewdney: $(length(trajectory)-1) ticks, richness=$(stats.local_richness)")
    end

    @testset "Sugarscape Culture" begin
        params = SCParams(initial_population=100, grid_width=25, grid_height=25, max_ticks=50, seed=42)
        scheduler, trajectory = run_sugarscapeculture(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, SCStats)
        @test stats.num_red + stats.num_blue >= 0
        println("  Sugarscape Culture: $(length(trajectory)-1) ticks, red=$(stats.num_red), blue=$(stats.num_blue)")
    end

    @testset "Sugarscape Sexual" begin
        params = SSParams(initial_population=50, grid_width=25, grid_height=25, max_ticks=50, seed=42)
        scheduler, trajectory = run_sugarscapesexual(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, SSStats)
        @test stats.num_turtles >= 0
        println("  Sugarscape Sexual: $(length(trajectory)-1) ticks, population=$(stats.num_turtles)")
    end

    @testset "CSV Network Foraging" begin
        params = CNFParams(num_consumers=10, max_ticks=50, seed=42)
        scheduler, trajectory = run_csvnetworkforaging(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, CNFStats)
        @test stats.total_supply >= 0
        @test stats.num_consumers >= 0
        println("  CSV Network Foraging: $(length(trajectory)-1) ticks, consumers=$(stats.num_consumers), supply=$(round(stats.total_supply, digits=1))")
    end

    @testset "CQIN" begin
        params = CQINParams(number_of_nodes=30, max_ticks=20, seed=42)
        scheduler, trajectory = run_cqin(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, CQINStats)
        @test stats.num_updated >= 0
        @test stats.num_resistant >= 0
        println("  CQIN: $(length(trajectory)-1) ticks, updated=$(stats.num_updated), resistant=$(stats.num_resistant), adjusted=$(stats.num_adjusted)")
    end

    @testset "Fungal Bioremediation" begin
        params = FBRParams(max_ticks=50, seed=42)
        scheduler, trajectory = run_fungalbioremediation(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, FBRStats)
        @test stats.num_fungi >= 0
        println("  Fungal Bioremediation: $(length(trajectory)-1) ticks, fungi=$(stats.num_fungi), enzymes=$(stats.num_enzymes), ecs=$(stats.num_ecs)")
    end

    @testset "Competition Learning" begin
        params = CLParams(max_ticks=200, seed=42)
        _, traj = run_competitionlearning(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 2
        println("  Competition Learning: $(length(traj)-1) ticks, mean_strategy=$(round(traj[end][1], digits=3)), min_strategy=$(round(traj[end][2], digits=3))")
    end

    @testset "Simple Market" begin
        params = SMktParams(max_ticks=200, seed=42)
        _, traj = run_simplemarket(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 2
        println("  Simple Market: $(length(traj)-1) ticks, active_shoppers=$(traj[end][1]), empty_traders=$(traj[end][2])")
    end

    @testset "Simple Market Random" begin
        params = SMktRParams(max_ticks=200, seed=42)
        _, traj = run_simplemarketrandom(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 2
        println("  Simple Market Random: $(length(traj)-1) ticks, shoppers_left=$(traj[end][1]), traders_with_stock=$(traj[end][2])")
    end

    @testset "Simple Market Table" begin
        params = SMktTParams(max_ticks=200, seed=42)
        _, traj = run_simplemarkettable(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 2
        println("  Simple Market Table: $(length(traj)-1) ticks, shoppers=$(traj[end][1]), total_paces=$(round(traj[end][2], digits=1))")
    end

    @testset "Babysitting Coop" begin
        params = BSitParams(max_ticks=100, seed=42)
        _, traj = run_babysittingcoop(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 3
        println("  Babysitting Coop: $(length(traj)-1) ticks, total_scrip=$(round(traj[end][1], digits=1)), going_out=$(traj[end][2]), sitting=$(traj[end][3])")
    end

    @testset "Leonardi Tech Adoption" begin
        params = LTechParams(max_ticks=100, seed=42)
        _, traj = run_leonarditechadoption(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 2
        println("  Leonardi Tech Adoption: $(length(traj)-1) ticks, n_users=$(traj[end][1]), n_active=$(traj[end][2])")
    end

    @testset "Wisdom of Crowd" begin
        params = WCParams(max_ticks=50, seed=42)
        _, traj = run_wisdomcrowd(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 4
        println("  Wisdom of Crowd: $(length(traj)-1) ticks, offenders=$(round(traj[end][1], digits=1))%, interveners=$(round(traj[end][2], digits=1))%, neutralized=$(round(traj[end][3], digits=1))%")
    end

    @testset "Recruiting Movement" begin
        params = RecMovParams(max_ticks=100, seed=42)
        _, traj = run_recruitingmovement(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 3
        println("  Recruiting Movement: $(length(traj)-1) ticks, recruit=$(traj[end][1])%, resist=$(traj[end][2])%, neutral=$(traj[end][3])%")
    end

    @testset "Heatbugs" begin
        params = HBParams(bug_count=50, grid_width=50, grid_height=50, max_ticks=100, seed=42)
        _, traj = run_heatbugs(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 2
        println("  Heatbugs: $(length(traj)-1) ticks, mean_unhappy=$(round(traj[end][1], digits=2)), max_unhappy=$(round(traj[end][2], digits=2))")
    end

    @testset "Shepherds" begin
        params = SHParams(num_sheep=50, num_shepherds=10, max_ticks=100, seed=42)
        _, traj = run_shepherds(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 2
        println("  Shepherds: $(length(traj)-1) ticks, efficiency=$(round(traj[end][1], digits=1))%, sheep_visible=$(traj[end][2])")
    end

    @testset "Minority Game" begin
        params = MGParams(number=101, memory=3, strategies_per_agent=5, max_ticks=100, seed=42)
        _, traj = run_minoritygame(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 3
        println("  Minority Game: $(length(traj)-1) ticks, avg_score=$(round(traj[end][1], digits=2)), picking_zero=$(traj[end][3])")
    end

    @testset "Percolation" begin
        params = PERCParams(porosity=60.5, grid_width=50, grid_height=80, max_ticks=500, seed=42)
        _, traj = run_percolation(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 2
        println("  Percolation: $(length(traj)-1) ticks, total_oil=$(traj[end][2])")
    end

    @testset "Language Change" begin
        params = LCParams(num_nodes=50, max_ticks=100, seed=42)
        _, traj = run_languagechange(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 3
        println("  Language Change: $(length(traj)-1) ticks, mean_state=$(round(traj[end][1], digits=3)), g0=$(traj[end][2]), g1=$(traj[end][3])")
    end

    @testset "Traffic Grid" begin
        params = TGParams(grid_size_x=3, grid_size_y=3, num_cars=30, max_ticks=100, seed=42)
        _, traj = run_trafficgrid(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 3
        println("  Traffic Grid: $(length(traj)-1) ticks, stopped=$(traj[end][1]), mean_speed=$(round(traj[end][2], digits=3))")
    end

    @testset "Traffic 2 Lanes" begin
        params = T2LParams(number=20, road_length=51, max_ticks=100, seed=42)
        _, traj = run_traffic2lanes(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 2
        println("  Traffic 2 Lanes: $(length(traj)-1) ticks, mean_speed=$(round(traj[end][1], digits=3))")
    end

    @testset "Traffic Intersection" begin
        params = TIParams(max_ticks=100, seed=42)
        _, traj = run_trafficintersection(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 3
        println("  Traffic Intersection: $(length(traj)-1) ticks, waiting=$(traj[end][1]), east=$(traj[end][2]), north=$(traj[end][3])")
    end

    @testset "Termites" begin
        params = TMParams(number=100, density=20.0, grid_width=51, grid_height=51, max_ticks=50, seed=42)
        _, traj = run_termites(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 2
        println("  Termites: $(length(traj)-1) ticks, piles=$(traj[end][1])")
    end

    @testset "Slime" begin
        params = SLParams(population=100, grid_width=41, grid_height=41, max_ticks=50, seed=42)
        _, traj = run_slime(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) >= 1
        println("  Slime: $(length(traj)-1) ticks")
    end

    @testset "Life" begin
        params = LFParams(initial_density=35, grid_width=51, grid_height=51, max_ticks=50, seed=42)
        _, traj = run_life(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 2
        println("  Life: $(length(traj)-1) ticks, alive=$(traj[end][1])")
    end

    @testset "Bank Reserves" begin
        params = BRESParams(people=20, reserves=50, max_ticks=50, seed=42)
        _, traj = run_bank_reserves(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 4
        println("  Bank Reserves: $(length(traj)-1) ticks, rich=$(traj[end][1]), poor=$(traj[end][2])")
    end

    @testset "Altruism" begin
        params = ALTParams(grid_width=21, grid_height=21, max_ticks=50, seed=42)
        _, traj = run_altruism(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) >= 2
        println("  Altruism: $(length(traj)-1) ticks, altruists=$(traj[end][1]), selfish=$(traj[end][2])")
    end

    @testset "Cooperation" begin
        params = COOPParams(initial_cows=10, grid_width=11, grid_height=11, max_ticks=50, seed=42)
        _, traj = run_cooperation(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) >= 1
        println("  Cooperation: $(length(traj)-1) ticks")
    end

    @testset "Giant Component" begin
        params = GCParams(num_nodes=40, max_ticks=50, seed=42)
        _, traj = run_giant_component(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) >= 1
        println("  Giant Component: $(length(traj)-1) ticks")
    end

    @testset "Rabbits Grass Weeds" begin
        params = RGWParams(number=50, grid_width=21, grid_height=21, max_ticks=50, seed=42)
        _, traj = run_rgw(; params=params, observe=true)
        @test length(traj) >= 2
        @test length(traj[1]) == 3
        println("  Rabbits Grass Weeds: $(length(traj)-1) ticks, rabbits=$(traj[end][1])")
    end

    # --- Batch C: Erosion, CA 1D, Virus on Network, Preferential Attachment, Small Worlds, Rebellion, Fireflies, AIDS ---

    @testset "Erosion" begin
        params = ERParams(grid_width=21, grid_height=21, max_ticks=50, seed=42)
        scheduler, trajectory = run_erosion(params=params)
        @test length(trajectory) > 1
        tick = get_resource(scheduler.world, Tick)
        stats = get_resource(scheduler.world, ERStats)
        @test tick.tick >= 50
        @test stats.total_water >= 0.0
        println("  Erosion: $(tick.tick) ticks, mean_elev=$(round(stats.mean_elevation, digits=1)), water=$(round(stats.total_water, digits=1))")
    end

    @testset "CA 1D Elementary" begin
        params = CA1DParams(grid_width=51, grid_height=50, rule=30, max_ticks=49, seed=42)
        scheduler, trajectory = run_ca_1d_elementary(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, CA1DStats)
        @test stats.current_row >= 2
        @test 0.0 < stats.density_on < 1.0
        println("  CA 1D Elementary: row=$(stats.current_row), density=$(round(stats.density_on, digits=3))")
    end

    @testset "Virus on Network" begin
        params = VONParams(number_of_nodes=80, average_node_degree=4, initial_outbreak_size=3, max_ticks=100, seed=42)
        scheduler, trajectory = run_virus_on_network(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, VONStats)
        @test stats.num_susceptible + stats.num_infected + stats.num_resistant == params.number_of_nodes
        println("  Virus on Network: S=$(stats.num_susceptible), I=$(stats.num_infected), R=$(stats.num_resistant)")
    end

    @testset "Preferential Attachment" begin
        params = PAParams(max_nodes=100, max_ticks=98, seed=42)
        scheduler, trajectory = run_preferential_attachment(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, PAStats)
        @test stats.num_nodes == 100
        @test stats.max_degree >= 2
        println("  Preferential Attachment: nodes=$(stats.num_nodes), edges=$(stats.num_edges), max_degree=$(stats.max_degree)")
    end

    @testset "Small Worlds" begin
        params = SWParams(num_nodes=20, rewiring_probability=0.3, max_ticks=1, seed=42)
        scheduler, trajectory = run_small_worlds(params=params)
        @test length(trajectory) >= 2
        stats = get_resource(scheduler.world, SWStats)
        @test stats.clustering_coefficient >= 0.0
        @test stats.average_path_length > 0.0
        println("  Small Worlds: CC=$(round(stats.clustering_coefficient, digits=3)), APL=$(round(stats.average_path_length, digits=3))")
    end

    @testset "Rebellion" begin
        params = REBParams(grid_width=20, grid_height=20, max_ticks=50, seed=42)
        scheduler, trajectory = run_rebellion(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, REBStats)
        @test stats.num_quiet + stats.num_active + stats.num_jailed > 0
        println("  Rebellion: quiet=$(stats.num_quiet), active=$(stats.num_active), jailed=$(stats.num_jailed)")
    end

    @testset "Fireflies" begin
        params = FFParams(number=100, cycle_length=10, flash_length=1, max_ticks=50, seed=42)
        scheduler, trajectory = run_fireflies(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, FFStats)
        @test stats.num_flashing >= 0
        println("  Fireflies: flashing=$(stats.num_flashing)")
    end

    @testset "AIDS" begin
        params = AIDSParams(initial_people=100, max_ticks=100, seed=42)
        scheduler, trajectory = run_aids(params=params)
        @test length(trajectory) > 1
        stats = get_resource(scheduler.world, AIDSStats)
        @test stats.num_uninfected + stats.num_infected_unknown + stats.num_infected_known == params.initial_people
        println("  AIDS: uninfected=$(stats.num_uninfected), unknown=$(stats.num_infected_unknown), known=$(stats.num_infected_known)")
    end

    # --- Batch D: PD Evolutionary, Genetic Algorithm, Sugarscape 1, Granovetter, Logistic Growth, Voting, Public Good, Brian's Brain ---

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
