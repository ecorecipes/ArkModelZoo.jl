# Minimal SIS Model
# Ring of agents; infected contact R0 random others; SIS dynamics

struct InitMSISSystem <: System end

function initialize!(::InitMSISSystem, world::World)
    params = get_resource(world, MinimalSISParams)
    st = get_resource(world, MSISState)
    stats = get_resource(world, MSISStats)

    st.n = params.population
    st.states = zeros(Int, st.n)
    st.marked = falses(st.n)

    # NetLogo: individual 0 starts infected
    st.states[1] = 1

    stats.reproduction_number = Float64(params.basic_reproduction_number)
    stats.new_infected = 1
    return nothing
end

struct MSISGoSystem <: System end

function update!(::MSISGoSystem, world::World)
    params = get_resource(world, MinimalSISParams)
    rng = get_resource(world, RNGResource).rng
    st = get_resource(world, MSISState)
    stats = get_resource(world, MSISStats)

    # NetLogo: if new-infected > 0 [a-go]
    if stats.new_infected <= 0
        get_resource(world, Terminate).stop = true
        return nothing
    end

    old_infected = stats.new_infected
    n = st.n
    R0 = params.basic_reproduction_number

    # Clear marks
    fill!(st.marked, false)

    # NetLogo: ask individuals [infect]
    # Shuffle order (NetLogo ask shuffles)
    order = collect(1:n)
    Random.shuffle!(rng, order)

    for who in order
        st.states[who] == 1 || continue
        # Shuffle range (population-1), pick R0 contacts
        # let values array:from-list shuffle range (population - 1)
        values = collect(0:(n-2))
        Random.shuffle!(rng, values)
        for idx in 1:min(R0, length(values))
            i2 = values[idx]
            # i3 = ((i2 + 1 + who_index) mod population)
            # who is 1-indexed, NetLogo who is 0-indexed
            i3 = mod(i2 + 1 + (who - 1), n) + 1
            st.marked[i3] = true
        end
    end

    # NetLogo: ask individuals [update]
    Random.shuffle!(rng, order)
    new_inf = 0
    for who in order
        if st.marked[who] && st.states[who] == 0
            st.states[who] = 1
            new_inf += 1
        elseif st.states[who] == 1
            st.states[who] = 0
        end
        st.marked[who] = false
    end

    stats.new_infected = new_inf
    if old_infected == 0
        stats.reproduction_number = 0.0
    else
        stats.reproduction_number = new_inf / old_infected
    end
    return nothing
end

struct MSISTerminationSystem <: System end

function update!(::MSISTerminationSystem, world::World)
    params = get_resource(world, MinimalSISParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
