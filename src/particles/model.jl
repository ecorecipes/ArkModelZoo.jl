function particles_world(; initial_capacity::Int = 2048)
    return World(
        ParticlePosition,
        ParticleHeading;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function particles_systems()
    return (
        InitParticlesSystem(),
        ParticleSystem(),
        ParticlesTerminationSystem(),
    )
end

function particles_model(params::ParticlesParams = ParticlesParams())
    world = particles_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, ParticleStats())
    scheduler = Scheduler(world, particles_systems())
    initialize!(scheduler)
    return scheduler
end

struct ParticlesObserver end

function particles_headers(::ParticlesObserver)
    return ["Collisions"]
end

function particles_values(::ParticlesObserver, world::World)
    stats = get_resource(world, ParticleStats)
    return Float64[stats.collisions]
end

function run_particles(; params::ParticlesParams = ParticlesParams(), observe::Bool = true)
    scheduler = particles_model(params)
    obs = ParticlesObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, particles_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, particles_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
