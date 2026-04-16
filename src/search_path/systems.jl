function _normalize_search_path_option(value::Union{AbstractString,Symbol})
    return replace(lowercase(String(value)), r"[^a-z0-9]+" => "")
end

function _validate_search_path_params(params::SearchPathParams)
    _normalize_search_path_option(params.target_movement) == "gangster3" ||
        error("search_path currently supports only target_movement = \"gangster3\".")
    _normalize_search_path_option(params.searcher_strategy) == "myideagangster3" ||
        error("search_path currently supports only searcher_strategy = \"myidea - gangster3\".")
    _normalize_search_path_option(params.target_known_movement) == "generated" ||
        error("search_path currently supports only target_known_movement = \"Generated\".")
    params.number_of_sensors == 0 ||
        error("search_path currently supports only the default no-sensor configuration.")
    !params.sensors_move ||
        error("search_path currently supports only sensors_move = false.")
    params.targets_catch ||
        error("search_path currently supports only targets_catch = true.")
    return nothing
end

@inline function _sample_uniform_destination(rng::AbstractRNG, candidates::Vector{Int})
    return candidates[rand(rng, 1:length(candidates))]
end

struct InitSearchPathSystem <: System end

function initialize!(::InitSearchPathSystem, world::World)
    params = get_resource(world, SearchPathParams)
    _validate_search_path_params(params)

    rng = get_resource(world, RNGResource).rng
    stats = get_resource(world, SearchPathStats)
    stats.number_caught = 0
    stats.confidence_prob = 0.0
    stats.confidence_prob_actual = 0.0
    stats.current_targets_found = 0
    stats.last_targets_found_sum = 0

    for _ in 1:params.number_of_targets
        new_entity!(world, (SearchPathCell(rand(rng, 1:SEARCH_PATH_GRID_SIZE)), SearchPathStatus(false), SearchPathTarget()))
    end

    for _ in 1:params.number_of_searchers
        new_entity!(world, (SearchPathCell(rand(rng, 1:SEARCH_PATH_GRID_SIZE)), SearchPathSearcher()))
    end

    return nothing
end

struct SearchPathSearcherMoveSystem <: System end

function update!(::SearchPathSearcherMoveSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    for (_, cells) in Query(world, (SearchPathCell,); with=(SearchPathSearcher,))
        @inbounds for i in eachindex(cells)
            candidates = SEARCH_PATH_SEARCHER_NEIGHBORS[cells[i].id]
            cells[i].id = _sample_uniform_destination(rng, candidates)
        end
    end
    return nothing
end

struct SearchPathTargetMoveSystem <: System end

function update!(::SearchPathTargetMoveSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    for (_, cells, statuses) in Query(world, (SearchPathCell, SearchPathStatus); with=(SearchPathTarget,))
        @inbounds for i in eachindex(cells)
            statuses[i].caught && continue
            candidates = SEARCH_PATH_TARGET_NEIGHBORS[cells[i].id]
            cells[i].id = _sample_uniform_destination(rng, candidates)
        end
    end
    return nothing
end

struct SearchPathCatchSystem <: System
    searcher_counts::Vector{Int}
end

SearchPathCatchSystem() = SearchPathCatchSystem(zeros(Int, SEARCH_PATH_GRID_SIZE))

function update!(system::SearchPathCatchSystem, world::World)
    params = get_resource(world, SearchPathParams)
    rng = get_resource(world, RNGResource).rng

    fill!(system.searcher_counts, 0)
    for (_, cells) in Query(world, (SearchPathCell,); with=(SearchPathSearcher,))
        @inbounds for i in eachindex(cells)
            system.searcher_counts[cells[i].id] += 1
        end
    end

    for (_, cells, statuses) in Query(world, (SearchPathCell, SearchPathStatus); with=(SearchPathTarget,))
        @inbounds for i in eachindex(cells)
            statuses[i].caught && continue
            n_searchers = system.searcher_counts[cells[i].id]
            n_searchers == 0 && continue
            p_detect = params.exponential_detection ?
                (1 - exp(-params.detection_rate * n_searchers)) * n_searchers :
                Float64(n_searchers)
            if p_detect * 100 > rand(rng, 0:99)
                statuses[i].caught = true
            end
        end
    end

    return nothing
end

struct SearchPathStatsSystem <: System end

function update!(::SearchPathStatsSystem, world::World)
    params = get_resource(world, SearchPathParams)
    stats = get_resource(world, SearchPathStats)

    caught = 0
    for (_, _, statuses) in Query(world, (SearchPathCell, SearchPathStatus); with=(SearchPathTarget,))
        @inbounds for i in eachindex(statuses)
            caught += statuses[i].caught
        end
    end

    stats.number_caught = caught
    stats.confidence_prob = 0.0
    stats.confidence_prob_actual = 100.0 * caught / params.number_of_targets
    stats.current_targets_found = caught - stats.last_targets_found_sum
    stats.last_targets_found_sum = caught
    return nothing
end

struct SearchPathTerminationSystem <: System end

function update!(::SearchPathTerminationSystem, world::World)
    params = get_resource(world, SearchPathParams)
    tick = get_resource(world, Tick)
    stats = get_resource(world, SearchPathStats)
    terminate = get_resource(world, Terminate)

    if stats.confidence_prob > params.end_on_confidence ||
       stats.number_caught >= params.number_of_targets ||
       tick.tick >= _search_path_total_time(params)
        terminate.stop = true
    end

    return nothing
end
