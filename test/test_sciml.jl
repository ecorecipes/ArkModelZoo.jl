using Test
using ArkModelZoo
using Random: Xoshiro
import SciMLBase

@testset "SciML interface" begin
    @testset "one step! function" begin
        @test ArkModelZoo.step! === SciMLBase.step!
        sched = daisyworld_model(DaisyworldParams(max_ticks = 3))
        @test step!(sched) === true
    end

    @testset "solve reproduces the model's own run" begin
        dp = DaisyworldParams(max_ticks = 60, seed = 3)
        _, traj = run_daisyworld(params = dp)
        sol = solve(DaisyworldProblem(dp; tspan = (0, length(traj) - 1)))
        cells = dp.grid_size^2
        # the model's own observer is filled from tick 1 on (its statistics are computed in a system)
        for k in 2:length(traj)
            @test sol.u[k] ≈ [traj[k][1], traj[k][2] / cells, traj[k][3] / cells]
        end
        @test sol.t == collect(0:length(traj) - 1)
        @test SciMLBase.successful_retcode(sol)

        wp = WolfSheepParams(max_ticks = 80, seed = 5)
        _, wtraj = run_wolfsheep(params = wp)
        wsol = solve(WolfSheepProblem(wp; tspan = (0, length(wtraj) - 1)))
        for k in 2:length(wtraj)
            @test wsol.u[k] == wtraj[k]
        end
    end

    @testset "integrator: stepping, saving and exact replay" begin
        prob = WolfSheepProblem(WolfSheepParams(seed = 11); tspan = (0, 100))
        integ = init(prob, TickStepping(); saveat = 10)
        step!(integ, 30, true)
        @test integ.t == 30
        @test_throws ArgumentError step!(integ, 2.5, true)
        u30 = copy(integ.u)
        step!(integ, 20, true)
        u50 = copy(integ.u)
        reinit!(integ)
        @test integ.t == 0
        step!(integ, 30, true)
        @test integ.u == u30
        step!(integ, 20, true)
        @test integ.u == u50
        sol = solve!(integ)
        @test sol.t == collect(0:10:100)
        @test SciMLBase.check_error(integ) == SciMLBase.ReturnCode.Success
        terminate!(integ)
        @test SciMLBase.successful_retcode(SciMLBase.check_error(integ))
    end

    @testset "setting the summary moves the world" begin
        integ = init(DaisyworldProblem(DaisyworldParams(seed = 2); tspan = (0, 200)))
        step!(integ, 50, true)
        cells = 29^2
        set_u!(integ, [integ.u[1] + 5.0, 0.10, 0.30])
        @test integ.u[2] ≈ round(Int, 0.10 * cells) / cells
        @test integ.u[3] ≈ round(Int, 0.30 * cells) / cells
        T = integ.u[1]
        @test_throws ArgumentError set_u!(integ, [T, 0.7, 0.5])
        # mutate in place, then flag it
        integ.u[2] = 0.0
        derivative_discontinuity!(integ, true)
        @test integ.u[2] == 0.0

        w = init(WolfSheepProblem(WolfSheepParams(seed = 4); tspan = (0, 100)))
        step!(w, 20, true)
        S, W, G = w.u
        set_u!(w, [S + 25, max(W - 5, 0), G - 10])
        @test w.u == [S + 25, max(W - 5, 0), G - 10]
        @test_throws ArgumentError set_u!(w, [-1.0, W, G])
        # NaN leaves a component alone
        set_u!(w, [NaN, 0.0, NaN])
        @test w.u[2] == 0.0 && w.u[1] == S + 25
    end

    @testset "a perturbation does not draw from the model's random numbers" begin
        prob = WolfSheepProblem(WolfSheepParams(seed = 8); tspan = (0, 120))
        a = init(prob)
        step!(a, 40, true)
        set_u!(a, copy(a.u))          # a change of nothing
        step!(a, 60, true)
        b = init(prob)
        step!(b, 100, true)
        @test a.u == b.u
    end

    @testset "u0, remake and parameters" begin
        prob = DaisyworldProblem(DaisyworldParams(seed = 1); u0 = [NaN, 0.3, 0.05], tspan = (0, 10))
        integ = init(prob)
        @test integ.u[2:3] ≈ [round(Int, 0.3 * 841), round(Int, 0.05 * 841)] ./ 841
        @test remake(prob; seed = 9).seed == 9
        @test remake(prob; u0 = nothing).u0 === nothing

        q = deepcopy(integ.p)
        q.solar_luminosity = 1.4
        integ.p = q
        @test ArkModelZoo.get_resource(integ.scheduler.world, ArkModelZoo.DaisyStats).solar_luminosity == 1.4
        r = deepcopy(q)
        r.grid_size = 10
        @test_throws ArgumentError (integ.p = r)
    end

    @testset "ensembles" begin
        prob = WolfSheepProblem(WolfSheepParams(); tspan = (0, 30))
        sim = solve(EnsembleProblem(prob), TickStepping(), EnsembleSerial(); trajectories = 3)
        finals = [s.u[end] for s in sim.u]
        @test length(unique(finals)) > 1           # each trajectory has its own seed
        sim2 = solve(EnsembleProblem(prob), TickStepping(), EnsembleSerial(); trajectories = 3)
        @test [s.u[end] for s in sim2.u] == finals # and is reproducible
    end

    @testset "DynamicalResilience metrics run on the models" begin
        prob = WolfSheepProblem(WolfSheepParams(seed = 21); tspan = (0, 200))
        r = recovery(prob, TickStepping(); perturb = (u, rng) -> [u[1] / 2, u[2], u[3]],
                     t_pulse = 100, horizon = 50, interval = 5, rng = Xoshiro(1))
        @test r.retcode == :Success
        @test length(r.t) == length(r.distance) == 11
        @test r.distance[1] > 0

        dprob = DaisyworldProblem(DaisyworldParams(seed = 5); u0 = [NaN, 0.2, 0.2], tspan = (0, 100))
        bs = basin_stability(dprob, TickStepping(); trajectories = 6, ensemble = EnsembleSerial(),
                             sample_perturbation = (u, rng) -> [NaN, 0.4rand(rng), 0.4rand(rng)],
                             returned = u -> u[2] + u[3] > 0.05, seed = 3)
        @test bs.trajectories == 6 && bs.failed == 0
        @test 0 ≤ bs.fraction ≤ 1

        ramp = (p, t) -> (q = deepcopy(p); q.solar_luminosity = 0.8 + 0.002t; q)
        series = ramped_series(DaisyworldProblem(DaisyworldParams(seed = 6); tspan = (0, 200)), TickStepping();
                               saveat = 0:2:200, ramp = ramp, observe = u -> u[1])
        @test length(series.x) == 101
        ew = early_warning(series.x; t = series.t, window = 0.5)
        @test isfinite(ew.tau_variance) && isfinite(ew.tau_ac1)
    end
end
