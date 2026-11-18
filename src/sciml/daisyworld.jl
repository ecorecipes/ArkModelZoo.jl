"""
    DaisyworldProblem(params = DaisyworldParams(); u0 = nothing, tspan = (0, params.max_ticks),
                      seed = params.seed)

Daisyworld as a SciML problem, advanced by [`TickStepping`](@ref).

The state is the summary `u = [T, w, b]`: `T` the mean temperature of the grid, `w` and `b`
the fractions of cells holding a white and a black daisy.

- `u0 = nothing` starts from the model's own random initial state (`start_pct_whites` and
  `start_pct_blacks` of the cells planted). A vector `u0` is then imposed on that state as
  `set_u!` would; an entry `NaN` leaves that component as initialised.
- **Setting a summary** (`set_u!`, `u0`, or a perturbation in `recovery`) moves the world by
  the smallest random change with that summary. Every cell's temperature is shifted by the same
  amount, so the spatial pattern is kept. Daisies of a colour are removed at random, or planted
  at random empty cells with ages drawn uniformly from `0:max_age` as at initialisation. Cover
  is rounded to whole cells, so `integ.u` after the change is the summary actually reached.
  These random choices use a stream kept apart from the model's, so a perturbation does not
  itself shift the model's random numbers (the streams still diverge afterwards, because the
  model draws one number per daisy).
- **`integ.p = q`** changes the parameters from the next tick on; `solar_luminosity` takes
  effect at once (unless `ramp_scenario` is set, in which case the model ramps it itself).
  `grid_size` cannot change.

The model's own stopping rule (`max_ticks`) is ignored: `tspan` sets the length of a run.
"""
struct DaisyworldProblem{U} <: AbstractArkProblem
    p::DaisyworldParams
    u0::U
    tspan::Tuple{Int,Int}
    seed::Int
end

function DaisyworldProblem(p::DaisyworldParams = DaisyworldParams(); u0 = nothing,
                           tspan = (0, p.max_ticks), seed::Integer = p.seed)
    u = _u0(u0)
    u === nothing || length(u) == 3 || throw(ArgumentError("a Daisyworld summary has 3 entries: [T, w, b]"))
    return DaisyworldProblem(deepcopy(p), u, _tspan(tspan), Int(seed))
end

SciMLBase.remake(prob::DaisyworldProblem; p = prob.p, u0 = prob.u0, tspan = prob.tspan, seed = prob.seed) =
    DaisyworldProblem(p; u0, tspan, seed)

_model(::DaisyworldProblem) = daisyworld_model

function _sync_params!(::DaisyworldProblem, world::World, q::DaisyworldParams)
    _copy_params!(get_resource(world, DaisyworldParams), q, (:grid_size,))
    q.ramp_scenario || (get_resource(world, DaisyStats).solar_luminosity = q.solar_luminosity)
    return world
end

function _daisies(world::World, tag)
    ids = Entity[]
    for (eids, _) in Query(world, (DaisyPosition,); with = (tag,))
        append!(ids, eids)
    end
    return ids
end

function _summary(::DaisyworldProblem, world::World)
    grid = get_resource(world, TemperatureGrid)
    cells = grid.width * grid.height
    return [mean(grid.temperature), length(_daisies(world, WhiteDaisy)) / cells,
            length(_daisies(world, BlackDaisy)) / cells]
end

function _remove_daisies!(world::World, grid::TemperatureGrid, ids, n, rng)
    for e in Iterators.take(shuffle!(rng, ids), n)
        pos = get_components(world, e, (DaisyPosition,))[1]
        grid.occupant[pos.x, pos.y] = zero_entity
        remove_entity!(world, e)
    end
end

function _plant_daisies!(world::World, grid::TemperatureGrid, params::DaisyworldParams, white::Bool, n, rng)
    empty = [(x, y) for x in 1:grid.width for y in 1:grid.height if is_zero(grid.occupant[x, y])]
    n ≤ length(empty) || throw(ArgumentError("not enough empty cells for $n more daisies"))
    shuffle!(rng, empty)
    for (x, y) in Iterators.take(empty, n)
        albedo, tag = white ? (params.white_albedo, WhiteDaisy()) : (params.black_albedo, BlackDaisy())
        eid = new_entity!(world, (DaisyPosition(x, y), DaisyAge(rand(rng, 0:params.max_age)), Albedo(albedo), tag))
        grid.occupant[x, y] = eid
    end
end

function _apply_summary!(prob::DaisyworldProblem, world::World, u, rng)
    length(u) == 3 || throw(ArgumentError("a Daisyworld summary has 3 entries: [T, w, b]"))
    grid = get_resource(world, TemperatureGrid)
    params = get_resource(world, DaisyworldParams)
    cells = grid.width * grid.height
    T, w, b = u
    for (name, c) in (("white", w), ("black", b))
        isnan(c) || 0 ≤ c ≤ 1 || throw(ArgumentError("$name cover must lie in [0, 1]; got $c"))
    end
    whites, blacks = _daisies(world, WhiteDaisy), _daisies(world, BlackDaisy)
    nw = isnan(w) ? length(whites) : round(Int, w * cells)
    nb = isnan(b) ? length(blacks) : round(Int, b * cells)
    nw + nb ≤ cells || throw(ArgumentError("white and black cover together exceed the grid"))
    # removals first, so that a swap of colours always fits
    nw < length(whites) && _remove_daisies!(world, grid, whites, length(whites) - nw, rng)
    nb < length(blacks) && _remove_daisies!(world, grid, blacks, length(blacks) - nb, rng)
    nw > length(whites) && _plant_daisies!(world, grid, params, true, nw - length(whites), rng)
    nb > length(blacks) && _plant_daisies!(world, grid, params, false, nb - length(blacks), rng)
    isnan(T) || (grid.temperature .+= T - mean(grid.temperature))
    return world
end
