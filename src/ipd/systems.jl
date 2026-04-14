# --- Initialization ---

struct InitIPDSystem <: System end

function initialize!(::InitIPDSystem, world::World)
    params = get_resource(world, IPDParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, IPDGrid)
    w, h = grid.width, grid.height

    for x in 1:w, y in 1:h
        grid.s_number[x, y] = rand(rng, 0:15)
        grid.previous_outcome[x, y] = rand(rng, 0:3)
        grid.recent_score[x, y] = 0
    end
    return nothing
end

# --- Decode move from strategy and previous outcome ---

function decode_move(s_number::Int, prev_outcome::Int)
    if prev_outcome == 0
        return (s_number >> 3) & 1
    elseif prev_outcome == 1
        return (s_number >> 2) & 1
    elseif prev_outcome == 2
        return (s_number >> 1) & 1
    else
        return s_number & 1
    end
end

# --- Play Phase ---

struct IPDPlaySystem <: System end

function update!(::IPDPlaySystem, world::World)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, IPDGrid)
    w, h = grid.width, grid.height
    s_number = grid.s_number
    previous_outcome = grid.previous_outcome
    recent_score = grid.recent_score

    # Von Neumann neighbors: N, E, S, W
    offsets = ((0, 1), (1, 0), (0, -1), (-1, 0))

    # Random order iteration (NetLogo ask patches)
    perm = randperm(rng, w * h)
    for idx in perm
        y = (idx - 1) ÷ w + 1
        x = (idx - 1) % w + 1

        # Pick a random neighbor
        dx, dy = offsets[rand(rng, 1:4)]
        nx = mod1(x + dx, w)
        ny = mod1(y + dy, h)

        # Decode moves
        my_go = decode_move(s_number[x, y], previous_outcome[x, y])
        their_go = decode_move(s_number[nx, ny], previous_outcome[nx, ny])

        # Update outcomes: 2*my_move + their_move
        previous_outcome[x, y] = 2 * my_go + their_go
        previous_outcome[nx, ny] = 2 * their_go + my_go

        # Update scores: 4 + my_go - 4*their_go + my_go*their_go
        recent_score[x, y] = 4 + my_go - 4 * their_go + my_go * their_go
        recent_score[nx, ny] = 4 + their_go - 4 * my_go + their_go * my_go
    end
    return nothing
end

# --- Evolve Phase ---

struct IPDEvolveSystem <: System end

function update!(::IPDEvolveSystem, world::World)
    params = get_resource(world, IPDParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, IPDGrid)
    w, h = grid.width, grid.height
    s_number = grid.s_number
    recent_score = grid.recent_score

    # Von Neumann neighbors: N, E, S, W
    offsets = ((0, 1), (1, 0), (0, -1), (-1, 0))

    # Random order iteration
    perm = randperm(rng, w * h)
    for idx in perm
        y = (idx - 1) ÷ w + 1
        x = (idx - 1) % w + 1

        if rand(rng) >= params.p_mutate
            # Copy best neighbor's strategy (reservoir sampling with ties)
            best_score = recent_score[x, y]
            best_s = s_number[x, y]
            tie_count = 1

            for (dx, dy) in offsets
                nx = mod1(x + dx, w)
                ny = mod1(y + dy, h)
                neighbor_score = recent_score[nx, ny]

                # Replicate NetLogo's two separate if statements (not if/else)
                if neighbor_score > best_score
                    best_score = neighbor_score
                    best_s = s_number[nx, ny]
                    tie_count = 1
                end
                if neighbor_score == best_score
                    tie_count += 1
                    if rand(rng, 0:(tie_count - 1)) == 0
                        best_s = s_number[nx, ny]
                    end
                end
            end
            s_number[x, y] = best_s
        else
            # Mutate: flip a random bit
            bit_to_flip = 1 << rand(rng, 0:3)
            s_number[x, y] = xor(s_number[x, y], bit_to_flip)
        end
    end
    return nothing
end

# --- Stats ---

struct IPDStatsSystem <: System end

function update!(::IPDStatsSystem, world::World)
    grid = get_resource(world, IPDGrid)
    stats = get_resource(world, IPDStats)
    stats.mean_score = mean(grid.recent_score)
    return nothing
end

# --- Termination ---

struct IPDTerminationSystem <: System end

function update!(::IPDTerminationSystem, world::World)
    params = get_resource(world, IPDParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
