abstract type System end

initialize!(::System, ::World) = nothing
update!(::System, ::World) = nothing
finalize!(::System, ::World) = nothing

mutable struct Scheduler{ST<:Tuple}
    world::World
    systems::ST
end

function initialize!(scheduler::Scheduler)
    for system in scheduler.systems
        initialize!(system, scheduler.world)
    end
    return scheduler
end

function step!(scheduler::Scheduler)
    if has_resource(scheduler.world, Terminate) && get_resource(scheduler.world, Terminate).stop
        return false
    end
    for system in scheduler.systems
        update!(system, scheduler.world)
    end
    get_resource(scheduler.world, Tick).tick += 1
    return true
end

function run!(scheduler::Scheduler)
    while step!(scheduler)
    end
    finalize!(scheduler)
    return scheduler
end

function finalize!(scheduler::Scheduler)
    for system in scheduler.systems
        finalize!(system, scheduler.world)
    end
    return scheduler
end
