# --- Initialization ---

struct InitSandSystem <: System end

function initialize!(::InitSandSystem, world::World)
    params = get_resource(world, SandParams)
    grid = get_resource(world, SandGrid)
    stats = get_resource(world, SandStats)
    w, h = grid.width, grid.height

    # NetLogo coords: pxcor = x - (w+1)/2, pycor = y - (h+1)/2
    # max_pycor = (h-1)/2 = 40
    # max_pxcor = (w-1)/2 = 40
    half_h = (h - 1) ÷ 2  # 40
    half_w = (w - 1) ÷ 2  # 40
    cx = half_w + 1  # center x in grid = 41
    cy = half_h + 1  # center y in grid = 41

    # surface_ycor = round(-0.8 * max_pycor) in NetLogo coords
    surface_ycor = round(Int, -0.8 * half_h)  # -32
    surface_y = surface_ycor + cy  # grid y = 9

    # Patches below surface are gray
    for x in 1:w, y in 1:h
        if y < surface_y
            grid.colors[x, y] = 2  # gray
        else
            grid.colors[x, y] = 0  # black
        end
    end

    # Spout patches
    spout_ycor = round(Int, 0.9 * half_h)  # 36
    spout_y = spout_ycor + cy  # grid y = 77
    spout_space = round(Int, 0.6 * half_w)  # 24

    empty!(grid.spout_patches)
    for x in 1:w
        pxcor = x - cx
        # NetLogo: pxcor mod spout_space == 0
        if spout_space > 0 && mod(pxcor, spout_space) == 0
            push!(grid.spout_patches, (x, spout_y))
            grid.colors[x, spout_y] = 3  # blue
        end
    end

    stats.n_brown = 0
    return nothing
end

# --- Update ---

struct SandUpdateSystem <: System end

@inline function wrap_x(x::Int, w::Int)
    return mod1(x, w)
end

function update!(::SandUpdateSystem, world::World)
    params = get_resource(world, SandParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, SandGrid)
    stats = get_resource(world, SandStats)
    tick = get_resource(world, Tick)
    w, h = grid.width, grid.height
    colors = grid.colors
    next_colors = grid.next_colors

    # --- Spout ---
    if mod(tick.tick, params.spacing) == 0
        for (sx, sy) in grid.spout_patches
            if rand(rng) * 100.0 <= params.release_chance
                # Release sand one below the spout
                below_y = sy - 1
                if below_y >= 1
                    colors[sx, below_y] = 1  # brown
                end
            end
        end
    end

    # --- Move all sand ---
    # Copy colors to next_colors
    copyto!(next_colors, colors)

    # Iterate brown patches in random order
    perm = randperm(rng, w * h)
    for idx in perm
        y = (idx - 1) ÷ w + 1
        x = (idx - 1) % w + 1
        colors[x, y] != 1 && continue  # only brown patches (using original colors)

        if y - 1 < 1
            # At bottom edge, can't fall (non-wrapping y)
            continue
        end

        below = colors[x, y - 1]
        if below == 0  # black below → fall straight down
            next_colors[x, y] = 0
            next_colors[x, y - 1] = 1
        else
            # Check diagonals
            left_x = wrap_x(x - 1, w)
            right_x = wrap_x(x + 1, w)
            left_below = colors[left_x, y - 1]
            right_below = colors[right_x, y - 1]

            if left_below == 1 && right_below == 0
                # Left-below is brown, right-below is black → move right
                next_colors[x, y] = 0
                next_colors[right_x, y - 1] = 1
            elseif left_below == 0 && right_below == 1
                # Left-below is black, right-below is brown → move left
                next_colors[x, y] = 0
                next_colors[left_x, y - 1] = 1
            elseif left_below == 0 && right_below == 0
                # Both black → random
                if rand(rng, Bool)
                    next_colors[x, y] = 0
                    next_colors[right_x, y - 1] = 1
                else
                    next_colors[x, y] = 0
                    next_colors[left_x, y - 1] = 1
                end
            end
            # else: both occupied or out-of-bounds, sand stays
        end
    end

    # Apply next_colors
    copyto!(colors, next_colors)

    # Count brown
    n_brown = 0
    for i in eachindex(colors)
        if colors[i] == 1
            n_brown += 1
        end
    end
    stats.n_brown = n_brown

    return nothing
end

# --- Termination ---

struct SandTerminationSystem <: System end

function update!(::SandTerminationSystem, world::World)
    params = get_resource(world, SandParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
