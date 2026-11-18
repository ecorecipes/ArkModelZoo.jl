# SciML problem and integrator interface for ArkModelZoo models, so that simulation-based
# resilience metrics (DynamicalResilience.jl: `recovery`, `basin_stability`, `ramped_series`,
# `early_warning`) and SciMLBase ensembles run on them unchanged.
#
# A model is advanced by its own systems, one tick at a time. The integrator's state `u` is a
# short summary vector of the world (documented for each model); writing a new summary with
# `set_u!` (or mutating `u` and calling `derivative_discontinuity!`) moves the world to a
# microstate with that summary by the smallest random change: agents are removed or added,
# chosen with a random stream kept apart from the model's own, so a perturbation does not by
# itself shift the model's random numbers.

"""
    AbstractArkProblem <: SciMLBase.AbstractSciMLProblem

Supertype of the ArkModelZoo models wrapped as SciML problems: [`DaisyworldProblem`](@ref)
and [`WolfSheepProblem`](@ref). Solve one with `solve(prob, TickStepping())`, step one with
`init`/`step!`, or run many with `EnsembleProblem`.
"""
abstract type AbstractArkProblem <: SciMLBase.AbstractSciMLProblem end

"""
    TickStepping()

The algorithm for an [`AbstractArkProblem`](@ref): the model's systems run once per tick, in
the model's own order. Time is the tick count, so steps and save times are whole numbers.
"""
struct TickStepping <: SciMLBase.AbstractSciMLAlgorithm end

_ticks(x::Integer) = Int(x)
function _ticks(x::Real)
    n = round(Int, x)
    abs(x - n) < 1e-8 || throw(ArgumentError("ticks are whole numbers; got $x"))
    return n
end

_tspan(t) = (_ticks(t[1]), _ticks(t[2]))

# a summary to apply at the start, or `nothing` to keep the model's own initial state
_u0(u0::Nothing) = nothing
_u0(u0) = collect(Float64, u0)

# random stream for perturbations, separate from the model's `Xoshiro(seed)`
_perturbation_rng(seed::Integer) = Xoshiro(reinterpret(UInt64, Int64(seed)) ⊻ 0x2545f4914f6cdd1d)

"""
    ArkIntegrator

The integrator returned by `init(prob::AbstractArkProblem, TickStepping())`. It implements the
part of SciML's integrator interface that simulation-based metrics use:

- `integ.u`: the summary vector of the current world; `integ.t`: the tick; `integ.p`: the
  parameters, which may be reassigned (`integ.p = q`) to change them from the next tick on,
  for example to ramp a forcing;
- `step!(integ)` (one tick) and `step!(integ, dt, stop_at_tdt = true)` (`dt` whole ticks);
- `reinit!(integ)`: rebuild the world from the problem and replay exactly, the random
  streams included;
- `set_u!(integ, u)`, or mutate `integ.u` and call `derivative_discontinuity!(integ, true)`:
  move the world to the summary `u` (see the problem's docstring for how);
- `terminate!`, `check_error`, `solve!`.
"""
mutable struct ArkIntegrator{Pr<:AbstractArkProblem,P}
    prob::Pr
    alg::TickStepping
    p::P
    scheduler::Scheduler
    seed::Int
    t::Int
    u::Vector{Float64}
    perturbation_rng::Xoshiro
    retcode::SciMLBase.ReturnCode.T
    terminated::Bool
    saveat::Union{Nothing,Vector{Int}}
    save_start::Bool
    ts::Vector{Int}
    us::Vector{Vector{Float64}}
end

function Base.setproperty!(integ::ArkIntegrator, name::Symbol, x)
    if name === :p
        setfield!(integ, :p, x)
        _sync_params!(integ.prob, integ.scheduler.world, x)
        return x
    end
    return setfield!(integ, name, convert(fieldtype(typeof(integ), name), x))
end

"""
    ArkSolution

The result of `solve(prob::AbstractArkProblem, TickStepping())`: the saved summaries `u`, their
ticks `t`, and a `retcode`. `sol.u[end]` is the final summary.
"""
struct ArkSolution{Pr<:AbstractArkProblem}
    u::Vector{Vector{Float64}}
    t::Vector{Int}
    prob::Pr
    alg::TickStepping
    retcode::SciMLBase.ReturnCode.T
end

SciMLBase.successful_retcode(sol::ArkSolution) = SciMLBase.successful_retcode(sol.retcode)
Base.length(sol::ArkSolution) = length(sol.u)

# copy every field of `q` into the parameter resource of `world`, refusing changes that the
# built world cannot follow
function _copy_params!(res, q, structural)
    for f in structural
        getfield(res, f) == getfield(q, f) ||
            throw(ArgumentError("`$f` cannot change once the world is built (it is $(getfield(res, f)))"))
    end
    for f in fieldnames(typeof(q))
        setfield!(res, f, getfield(q, f))
    end
    return res
end

# advance the world by one tick: the model's systems in order, then the tick counter. Unlike
# `step!(scheduler)` this ignores the model's own stopping rule, so `tspan` decides the length.
function _tick!(scheduler::Scheduler)
    for system in scheduler.systems
        update!(system, scheduler.world)
    end
    get_resource(scheduler.world, Tick).tick += 1
    return scheduler
end

function _build(prob::AbstractArkProblem, p, seed)
    q = deepcopy(p)
    q.seed = seed
    return _model(prob)(q)
end

function _start!(integ::ArkIntegrator, u0)
    integ.scheduler = _build(integ.prob, integ.p, integ.seed)
    integ.perturbation_rng = _perturbation_rng(integ.seed)
    u0 === nothing || _apply_summary!(integ.prob, integ.scheduler.world, u0, integ.perturbation_rng)
    integ.u = _summary(integ.prob, integ.scheduler.world)
    return integ
end

_saves(integ::ArkIntegrator, t) = integ.saveat === nothing || insorted(t, integ.saveat)

function _save!(integ::ArkIntegrator)
    if _saves(integ, integ.t)
        push!(integ.ts, integ.t)
        push!(integ.us, copy(integ.u))
    end
    return integ
end

function _savetimes(saveat, (t0, tf))
    saveat === nothing && return nothing
    if saveat isa Real
        step = _ticks(saveat)
        step > 0 || throw(ArgumentError("saveat must be positive"))
        return collect(t0:step:tf)
    end
    return sort!(unique!([_ticks(s) for s in saveat]))
end

function SciMLBase.init(prob::AbstractArkProblem, alg::TickStepping = TickStepping();
                        seed::Integer = prob.seed, saveat = nothing, save_start::Bool = true,
                        save_everystep = nothing, verbose = nothing, kwargs...)
    isempty(kwargs) || @warn "ignored keyword arguments: $(join(keys(kwargs), ", "))" maxlog = 1
    t0, tf = prob.tspan
    p = deepcopy(prob.p)
    integ = ArkIntegrator(prob, alg, p, _build(prob, p, seed), Int(seed), t0, Float64[],
                          _perturbation_rng(seed), SciMLBase.ReturnCode.Default, false,
                          _savetimes(saveat, (t0, tf)), save_start, Int[], Vector{Float64}[])
    _start!(integ, prob.u0)
    save_start && _save!(integ)
    return integ
end

function _advance!(integ::ArkIntegrator)
    integ.terminated && return integ
    _tick!(integ.scheduler)
    integ.t += 1
    integ.u = _summary(integ.prob, integ.scheduler.world)
    _save!(integ)
    return integ
end

SciMLBase.step!(integ::ArkIntegrator) = _advance!(integ)

function SciMLBase.step!(integ::ArkIntegrator, dt, stop_at_tdt::Bool = false)
    n = _ticks(dt)
    n ≥ 0 || throw(ArgumentError("cannot step backwards (dt = $dt)"))
    for _ in 1:n
        _advance!(integ)
    end
    return integ
end

function SciMLBase.solve!(integ::ArkIntegrator)
    tf = last(integ.prob.tspan)
    while integ.t < tf && !integ.terminated
        _advance!(integ)
    end
    code = integ.terminated ? integ.retcode : SciMLBase.ReturnCode.Success
    integ.retcode = code
    return ArkSolution(integ.us, integ.ts, integ.prob, integ.alg, code)
end

SciMLBase.solve(prob::AbstractArkProblem, alg::TickStepping = TickStepping(); kwargs...) =
    SciMLBase.solve!(SciMLBase.init(prob, alg; kwargs...))

function SciMLBase.reinit!(integ::ArkIntegrator, u0 = integ.prob.u0; t0 = first(integ.prob.tspan),
                           erase_sol::Bool = true, kwargs...)
    integ.t = _ticks(t0)
    integ.terminated = false
    integ.retcode = SciMLBase.ReturnCode.Default
    _start!(integ, u0 === nothing ? nothing : _u0(u0))
    if erase_sol
        empty!(integ.ts)
        empty!(integ.us)
        integ.save_start && _save!(integ)
    end
    return integ
end

function _impose!(integ::ArkIntegrator, u)
    _apply_summary!(integ.prob, integ.scheduler.world, u, integ.perturbation_rng)
    integ.u = _summary(integ.prob, integ.scheduler.world)
    return integ
end

function SciMLBase.set_u!(integ::ArkIntegrator, u)
    length(u) == length(integ.u) ||
        throw(ArgumentError("the summary has $(length(integ.u)) entries; got $(length(u))"))
    return _impose!(integ, collect(Float64, u))
end

function SciMLBase.derivative_discontinuity!(integ::ArkIntegrator, modified::Bool)
    modified && _impose!(integ, copy(integ.u))
    return integ
end

SciMLBase.u_modified!(integ::ArkIntegrator, modified::Bool) = SciMLBase.derivative_discontinuity!(integ, modified)

function SciMLBase.terminate!(integ::ArkIntegrator, retcode = SciMLBase.ReturnCode.Terminated)
    integ.terminated = true
    integ.retcode = retcode
    return integ
end

SciMLBase.check_error(integ::ArkIntegrator) = integ.terminated ? integ.retcode : SciMLBase.ReturnCode.Success

"""
    seed_trajectory(prob, ctx)

The default `prob_func` of an `EnsembleProblem` built on an [`AbstractArkProblem`](@ref):
trajectory `i` is `remake(prob; seed = prob.seed + i)`, or uses the seed SciMLBase derives when
the ensemble is solved with a `seed` keyword. Without it every trajectory would repeat the same
random numbers. (A `prob_func` of your own, such as the one `basin_stability` uses, keeps
`prob.seed` unless it sets `seed`: trajectories then differ only in what the function changes.)
"""
function seed_trajectory(prob::AbstractArkProblem, ctx)
    seed = ctx.sim_seed === nothing ? prob.seed + ctx.sim_id : Int(ctx.sim_seed % UInt(typemax(Int)))
    return SciMLBase.remake(prob; seed = seed)
end

function SciMLBase.EnsembleProblem(prob::AbstractArkProblem; prob_func = seed_trajectory,
                                   safetycopy::Bool = false, kwargs...)
    return invoke(SciMLBase.EnsembleProblem, Tuple{Any}, prob; prob_func, safetycopy, kwargs...)
end
