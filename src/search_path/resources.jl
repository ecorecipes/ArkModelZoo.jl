const SEARCH_PATH_GRID_LENGTH = 10
const SEARCH_PATH_GRID_SIZE = SEARCH_PATH_GRID_LENGTH^2

const SEARCH_PATH_SEARCHER_BLOCKED_EDGES = Set([
    (50, 60),
    (51, 61),
    (58, 68),
    (61, 71),
    (62, 72),
    (63, 73),
    (64, 74),
    (65, 75),
    (66, 76),
    (71, 61),
    (72, 62),
    (73, 63),
    (74, 64),
    (75, 65),
    (76, 66),
    (82, 92),
    (83, 93),
    (84, 94),
    (88, 89),
    (89, 88),
    (92, 82),
    (93, 83),
    (95, 85),
    (96, 86),
    (97, 87),
    (98, 99),
    (99, 98),
])

@inline function _search_path_cell(x::Int, y::Int)
    return (x - 1) * SEARCH_PATH_GRID_LENGTH + y
end

const SEARCH_PATH_TARGET_NEIGHBORS = let
    rows = [Int[] for _ in 1:SEARCH_PATH_GRID_SIZE]
    for cell in 1:SEARCH_PATH_GRID_SIZE
        x = fld(cell - 1, SEARCH_PATH_GRID_LENGTH) + 1
        y = mod(cell - 1, SEARCH_PATH_GRID_LENGTH) + 1
        for dx in -1:1, dy in -1:1
            nx = x + dx
            ny = y + dy
            if 1 <= nx <= SEARCH_PATH_GRID_LENGTH && 1 <= ny <= SEARCH_PATH_GRID_LENGTH
                push!(rows[cell], _search_path_cell(nx, ny))
            end
        end
    end
    rows
end

const SEARCH_PATH_SEARCHER_NEIGHBORS = let
    [Int[
        dest for dest in SEARCH_PATH_TARGET_NEIGHBORS[cell]
        if (cell, dest) ∉ SEARCH_PATH_SEARCHER_BLOCKED_EDGES
    ] for cell in 1:SEARCH_PATH_GRID_SIZE]
end

mutable struct SearchPathStats
    number_caught::Int
    confidence_prob::Float64
    confidence_prob_actual::Float64
    current_targets_found::Int
    last_targets_found_sum::Int
end

SearchPathStats() = SearchPathStats(0, 0.0, 0.0, 0, 0)
