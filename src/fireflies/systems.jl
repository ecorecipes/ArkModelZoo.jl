struct InitFFSystem <: System end

function initialize!(::InitFFSystem, world::World)
    params = get_resource(world, FFParams)
    rng = get_resource(world, RNGResource).rng

    for _ in 1:params.number
        x = rand(rng) * params.grid_width
        y = rand(rng) * params.grid_height
        clock = rand(rng, 0:params.cycle_length - 1)
        threshold = params.flash_length
        if params.strategy == :delay
            reset_level = threshold
            window = -1
        else  # :advance
            reset_level = 0
            window = threshold + 1
        end
        flashing = clock < threshold
        new_entity!(world, (FFFirefly(x, y, clock, threshold, reset_level, window, flashing),))
    end

    _ff_update_stats!(world)
    return nothing
end

struct FFGoSystem <: System end

function update!(::FFGoSystem, world::World)
    params = get_resource(world, FFParams)
    rng = get_resource(world, RNGResource).rng

    # First pass: move, increment clock, look (in shuffled order)
    fireflies = Tuple{Entity, FFFirefly}[]
    for (eids, ffs) in Query(world, (FFFirefly,))
        @inbounds for i in eachindex(ffs)
            push!(fireflies, (eids[i], ffs[i]))
        end
    end
    Random.shuffle!(rng, fireflies)

    w = Float64(params.grid_width)
    h = Float64(params.grid_height)

    for (_, ff) in fireflies
        # Move: rt random 90 - random 90; fd 1
        heading = (rand(rng) * 90.0 - rand(rng) * 90.0) * π / 180.0
        ff.x = mod(ff.x + sin(heading), w)
        ff.y = mod(ff.y + cos(heading), h)

        # Increment clock
        ff.clock += 1
        if ff.clock >= params.cycle_length
            ff.clock = 0
        end

        # Look: if clock > window and clock >= threshold, check neighbors
        if ff.clock > ff.window && ff.clock >= ff.threshold
            # Count flashing neighbors within radius 1
            n_flashing = 0
            for (_, ff2) in fireflies
                ff2 === ff && continue
                dx = abs(ff.x - ff2.x)
                dx = min(dx, w - dx)
                dy = abs(ff.y - ff2.y)
                dy = min(dy, h - dy)
                if dx^2 + dy^2 <= 1.0
                    if ff2.flashing
                        n_flashing += 1
                    end
                end
            end
            if n_flashing >= params.flashes_to_reset
                ff.clock = ff.reset_level
            end
        end
    end

    # Second pass: recolor (update flashing state)
    for (_, ff) in fireflies
        ff.flashing = ff.clock < ff.threshold
    end

    _ff_update_stats!(world)
    return nothing
end

function _ff_update_stats!(world::World)
    stats = get_resource(world, FFStats)
    n = 0
    for (_, ffs) in Query(world, (FFFirefly,))
        @inbounds for i in eachindex(ffs)
            if ffs[i].flashing
                n += 1
            end
        end
    end
    stats.num_flashing = n
end

struct FFTerminationSystem <: System end

function update!(::FFTerminationSystem, world::World)
    params = get_resource(world, FFParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
