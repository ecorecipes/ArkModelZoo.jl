# Mailmen (Letter Delivery) – ECS systems matching the NetLogo reference.
# Execution order: init → deliver → stats → termination
#
# NetLogo semantics: each tick, mailmen deliver letters sequentially (ask mailmen).
# Each mailman either goes to nearest carried letter's destination and drops it,
# or goes to nearest uncarried letter and picks up all letters at that patch.
# Movement is instantaneous (goto-xy teleports).

# --- Helpers ---

# Toroidal wrapped Euclidean distance
function _mailmen_distancexy(x1::Float64, y1::Float64, x2::Float64, y2::Float64, w::Float64, h::Float64)
    dx = abs(x1 - x2)
    dx = min(dx, w - dx)
    dy = abs(y1 - y2)
    dy = min(dy, h - dy)
    return sqrt(dx * dx + dy * dy)
end

# Toroidal wrapped heading from (x1,y1) towards (x2,y2), in degrees (NetLogo convention)
function _mailmen_towardsxy(x1::Float64, y1::Float64, x2::Float64, y2::Float64, w::Float64, h::Float64)
    dx = x2 - x1
    if dx > w / 2
        dx -= w
    elseif dx < -w / 2
        dx += w
    end
    dy = y2 - y1
    if dy > h / 2
        dy -= h
    elseif dy < -h / 2
        dy += h
    end
    return atan(dx, dy) * 180.0 / π  # atan(dx,dy) gives angle from north
end

# Move forward by `steps` in direction `heading` (degrees), wrapping toroidally
function _mailmen_fd!(pos, heading_deg::Float64, steps::Float64, w::Float64, h::Float64)
    rad = heading_deg * π / 180.0
    pos.x = mod(pos.x + sin(rad) * steps, w)
    pos.y = mod(pos.y + cos(rad) * steps, h)
    return nothing
end

# --- Initialization ---
# NetLogo: create-mailmen 5 [setxy get-random-xcor get-random-ycor]
#          create-letters 30 [setxy ... ; set destination-x/y get-random-xcor/ycor; set carrier nobody]

struct InitMailmenSystem <: System end

function initialize!(::InitMailmenSystem, world::World)
    params = get_resource(world, MailmenParams)
    rng = get_resource(world, RNGResource).rng
    registry = get_resource(world, MailmenRegistry)
    stats = get_resource(world, MailmenStats)
    wspan = params.max_coord - params.min_coord + 1  # 21

    # Create mailmen
    empty!(registry.mailman_entities)
    for i in 1:params.num_mailmen
        x = Float64(rand(rng, 0:wspan-1) + params.min_coord)
        y = Float64(rand(rng, 0:wspan-1) + params.min_coord)
        e = new_entity!(world, (
            MailmanPosition(x - params.min_coord, y - params.min_coord),
            MailmanState(0.0, 0.0),
        ))
        push!(registry.mailman_entities, e)
    end

    # Create letters
    empty!(registry.letter_entities)
    for _ in 1:params.num_letters
        x = Float64(rand(rng, 0:wspan-1) + params.min_coord)
        y = Float64(rand(rng, 0:wspan-1) + params.min_coord)
        dx = rand(rng, 0:wspan-1) + params.min_coord
        dy = rand(rng, 0:wspan-1) + params.min_coord
        e = new_entity!(world, (
            LetterPosition(x - params.min_coord, y - params.min_coord),
            LetterDest(dx, dy),
            LetterState(LUncarried, 0),
        ))
        push!(registry.letter_entities, e)
    end

    stats.total_dist = 0.0
    stats.num_remaining = params.num_letters
    return nothing
end

# --- Deliver Letters ---
# NetLogo: ask mailmen [deliver-letters]
# Each mailman:
#   my-letters = letters with [carrier = who-of-myself]
#   if any? my-letters → goto nearest destination, drop
#   else → goto nearest uncarried letter, pick up all at patch

# NetLogo goto-xy: only update heading when steps >= 1, then fd steps from current heading.
# After drop-letter, heading is reset to 0.
function _mailmen_goto_xy!(mpos::MailmanPosition, mstate::MailmanState,
                            tx::Float64, ty::Float64, w::Float64, h::Float64)
    steps = _mailmen_distancexy(mpos.x, mpos.y, tx, ty, w, h)
    if steps >= 1.0
        mstate.heading = _mailmen_towardsxy(mpos.x, mpos.y, tx, ty, w, h)
    end
    _mailmen_fd!(mpos, mstate.heading, steps, w, h)
    mstate.distance_travelled += steps
    return steps
end

struct MailmenDeliverSystem <: System end

function update!(::MailmenDeliverSystem, world::World)
    params = get_resource(world, MailmenParams)
    rng = get_resource(world, RNGResource).rng
    registry = get_resource(world, MailmenRegistry)
    wspan = params.max_coord - params.min_coord + 1
    w = Float64(wspan)
    h = Float64(wspan)

    # NetLogo: ask mailmen (random order each tick)
    order = randperm(rng, params.num_mailmen)

    for idx in order
        me = registry.mailman_entities[idx]
        mpos, mstate = get_components(world, me, (MailmanPosition, MailmanState))

        # Find my carried letters
        my_letter_indices = Int[]
        for (li, le) in enumerate(registry.letter_entities)
            ls = get_components(world, le, (LetterState,))[1]
            if ls.status == LCarried && ls.carrier == idx
                push!(my_letter_indices, li)
            end
        end

        if !isempty(my_letter_indices)
            # Go to nearest carried letter's destination
            best_li = 0
            best_dist = Inf
            for li in my_letter_indices
                le = registry.letter_entities[li]
                ldest = get_components(world, le, (LetterDest,))[1]
                dx = Float64(ldest.destination_x - params.min_coord)
                dy = Float64(ldest.destination_y - params.min_coord)
                d = _mailmen_distancexy(mpos.x, mpos.y, dx, dy, w, h)
                if d < best_dist
                    best_dist = d
                    best_li = li
                end
            end

            le = registry.letter_entities[best_li]
            ldest = get_components(world, le, (LetterDest,))[1]
            tx = Float64(ldest.destination_x - params.min_coord)
            ty = Float64(ldest.destination_y - params.min_coord)

            # goto-xy: matches NetLogo fd-based movement
            _mailmen_goto_xy!(mpos, mstate, tx, ty, w, h)

            # Move carried letters to mailman's position
            for li in my_letter_indices
                le2 = registry.letter_entities[li]
                lpos = get_components(world, le2, (LetterPosition,))[1]
                lpos.x = mpos.x
                lpos.y = mpos.y
            end

            # drop-letter: uncarry, check delivery, reset heading
            le_state = get_components(world, le, (LetterState,))[1]
            le_state.carrier = 0
            le_state.status = LUncarried

            mx_nl = mpos.x + params.min_coord
            my_nl = mpos.y + params.min_coord
            if round(Int, mx_nl) == ldest.destination_x && round(Int, my_nl) == ldest.destination_y
                le_state.status = LDelivered
            end
            # NetLogo: drop-letter ends with "set heading 0"
            mstate.heading = 0.0
        else
            # Go to nearest uncarried letter
            best_li = 0
            best_dist = Inf
            for (li, le) in enumerate(registry.letter_entities)
                ls = get_components(world, le, (LetterState,))[1]
                if ls.status == LUncarried
                    lpos = get_components(world, le, (LetterPosition,))[1]
                    d = _mailmen_distancexy(mpos.x, mpos.y, lpos.x, lpos.y, w, h)
                    if d < best_dist
                        best_dist = d
                        best_li = li
                    end
                end
            end

            if best_li == 0
                continue  # no uncarried letters
            end

            le = registry.letter_entities[best_li]
            lpos = get_components(world, le, (LetterPosition,))[1]

            # goto-xy: matches NetLogo fd-based movement
            _mailmen_goto_xy!(mpos, mstate, lpos.x, lpos.y, w, h)

            # Pickup all uncarried letters at this patch (same rounded coords)
            mx_nl = mpos.x + params.min_coord
            my_nl = mpos.y + params.min_coord
            mx_r = round(Int, mx_nl)
            my_r = round(Int, my_nl)
            for (li2, le2) in enumerate(registry.letter_entities)
                ls2 = get_components(world, le2, (LetterState,))[1]
                if ls2.status == LUncarried
                    lpos2 = get_components(world, le2, (LetterPosition,))[1]
                    lx_nl = lpos2.x + params.min_coord
                    ly_nl = lpos2.y + params.min_coord
                    if round(Int, lx_nl) == mx_r && round(Int, ly_nl) == my_r
                        ls2.status = LCarried
                        ls2.carrier = idx
                    end
                end
            end
        end
    end
    return nothing
end

# --- Statistics ---
# NetLogo: set total-dist sum [distance-travelled] of mailmen
#          set num-remaining count letters

struct MailmenStatsSystem <: System end

function update!(::MailmenStatsSystem, world::World)
    stats = get_resource(world, MailmenStats)
    registry = get_resource(world, MailmenRegistry)

    total = 0.0
    for me in registry.mailman_entities
        mstate = get_components(world, me, (MailmanState,))[1]
        total += mstate.distance_travelled
    end
    stats.total_dist = total

    remaining = 0
    for le in registry.letter_entities
        ls = get_components(world, le, (LetterState,))[1]
        if ls.status != LDelivered
            remaining += 1
        end
    end
    stats.num_remaining = remaining
    return nothing
end

# --- Termination ---
# NetLogo: if (not any? letters) [stop]  — stops when all delivered
# Also stop at max_ticks

struct MailmenTerminationSystem <: System end

function update!(::MailmenTerminationSystem, world::World)
    params = get_resource(world, MailmenParams)
    tick = get_resource(world, Tick)
    stats = get_resource(world, MailmenStats)
    if stats.num_remaining == 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
