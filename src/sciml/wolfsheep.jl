"""
    WolfSheepProblem(params = WolfSheepParams(); u0 = nothing, tspan = (0, params.max_ticks),
                     seed = params.seed)

Wolf–Sheep predation as a SciML problem, advanced by [`TickStepping`](@ref).

The state is the summary `u = [S, W, G]`: the numbers of sheep, of wolves and of green grass
patches (`G = 0` when grass is disabled).

- `u0 = nothing` starts from the model's own random initial state. A vector `u0` is then
  imposed on that state as `set_u!` would; an entry `NaN` leaves that component as
  initialised.
- **Setting a summary** (`set_u!`, `u0`, or a perturbation in `recovery`) moves the world by
  the smallest random change with that summary:
  - animals are removed at random, or added as at initialisation: a uniform random position, a
    random heading, and energy drawn from `0:9`;
  - grass patches are turned brown (countdown drawn from `1:grass_regrowth_time`) or green,
    at random.

  Counts are rounded to whole animals and patches. The random choices use a stream kept apart
  from the model's, so a perturbation does not itself shift the model's random numbers (the
  streams diverge afterwards, because the model draws numbers per animal).
- **`integ.p = q`** changes the parameters from the next tick on; the grid size cannot change.

The model's own stopping rules (both species extinct, `max_ticks`) are ignored: `tspan` sets
the length of a run, and the grass keeps growing after the animals are gone.
"""
struct WolfSheepProblem{U} <: AbstractArkProblem
    p::WolfSheepParams
    u0::U
    tspan::Tuple{Int,Int}
    seed::Int
end

function WolfSheepProblem(p::WolfSheepParams = WolfSheepParams(); u0 = nothing,
                          tspan = (0, p.max_ticks), seed::Integer = p.seed)
    u = _u0(u0)
    u === nothing || length(u) == 3 || throw(ArgumentError("a Wolf–Sheep summary has 3 entries: [S, W, G]"))
    return WolfSheepProblem(deepcopy(p), u, _tspan(tspan), Int(seed))
end

SciMLBase.remake(prob::WolfSheepProblem; p = prob.p, u0 = prob.u0, tspan = prob.tspan, seed = prob.seed) =
    WolfSheepProblem(p; u0, tspan, seed)

_model(::WolfSheepProblem) = wolfsheep_model

function _sync_params!(::WolfSheepProblem, world::World, q::WolfSheepParams)
    _copy_params!(get_resource(world, WolfSheepParams), q, (:grid_width, :grid_height))
    return world
end

function _animals(world::World, tag)
    ids = Entity[]
    for (eids, _) in Query(world, (WSPosition,); with = (tag,))
        append!(ids, eids)
    end
    return ids
end

function _green(world::World)
    params = get_resource(world, WolfSheepParams)
    params.grass_enabled || return 0
    return count(≤(0), get_resource(world, GrassGrid).countdown)
end

_summary(::WolfSheepProblem, world::World) =
    Float64[length(_animals(world, Sheep)), length(_animals(world, Wolf)), _green(world)]

function _set_animals!(world::World, tag, n, rng)
    ids = _animals(world, tag)
    if n < length(ids)
        for e in Iterators.take(shuffle!(rng, ids), length(ids) - n)
            remove_entity!(world, e)
        end
    else
        grid = get_resource(world, GrassGrid)
        w, h = grid.width, grid.height
        for _ in 1:(n - length(ids))
            new_entity!(world, (WSPosition(rand(rng) * w, rand(rng) * h), Energy(Float64(rand(rng, 0:9))),
                                WSHeading(Float64(rand(rng, 0:359))), tag()))
        end
    end
end

function _set_grass!(world::World, n, rng)
    params = get_resource(world, WolfSheepParams)
    grid = get_resource(world, GrassGrid)
    if !params.grass_enabled
        n == 0 || throw(ArgumentError("grass is disabled, so the green count must be 0"))
        return
    end
    n ≤ length(grid.countdown) || throw(ArgumentError("only $(length(grid.countdown)) grass patches"))
    green = findall(≤(0), grid.countdown)
    brown = findall(>(0), grid.countdown)
    if n < length(green)
        for i in Iterators.take(shuffle!(rng, green), length(green) - n)
            grid.countdown[i] = rand(rng, 1:params.grass_regrowth_time)
        end
    elseif n > length(green)
        for i in Iterators.take(shuffle!(rng, brown), n - length(green))
            grid.countdown[i] = 0
        end
    end
end

function _count(x, what)
    isnan(x) && return nothing
    x ≥ 0 || throw(ArgumentError("the number of $what cannot be negative; got $x"))
    return round(Int, x)
end

function _apply_summary!(::WolfSheepProblem, world::World, u, rng)
    length(u) == 3 || throw(ArgumentError("a Wolf–Sheep summary has 3 entries: [S, W, G]"))
    S, W, G = _count(u[1], "sheep"), _count(u[2], "wolves"), _count(u[3], "green patches")
    S === nothing || _set_animals!(world, Sheep, S, rng)
    W === nothing || _set_animals!(world, Wolf, W, rng)
    G === nothing || _set_grass!(world, G, rng)
    return world
end
