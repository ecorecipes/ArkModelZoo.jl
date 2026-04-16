const SEARCH_PATH_DEFAULT_TOTAL_TIME = 10_000

Base.@kwdef mutable struct SearchPathParams
    number_of_searchers::Int = 1
    number_of_sensors::Int = 0
    number_of_targets::Int = 1
    total_time::Int = SEARCH_PATH_DEFAULT_TOTAL_TIME
    max_ticks::Int = SEARCH_PATH_DEFAULT_TOTAL_TIME
    detection_rate::Float64 = 0.2
    number_of_known_targets::Int = 1
    end_on_confidence::Float64 = 100.0
    sensors_move::Bool = false
    exponential_detection::Bool = true
    targets_catch::Bool = true
    sensors_report_target::Bool = true
    target_movement::Union{String,Symbol} = :gangster3
    searcher_strategy::Union{String,Symbol} = :myidea_gangster3
    target_known_movement::Union{String,Symbol} = :generated
    seed::Int = 42
end

function _search_path_total_time(params::SearchPathParams)
    if params.total_time != SEARCH_PATH_DEFAULT_TOTAL_TIME || params.max_ticks == SEARCH_PATH_DEFAULT_TOTAL_TIME
        return params.total_time
    end
    return params.max_ticks
end
