mutable struct REBGrid
    width::Int
    height::Int
    cells::Matrix{Entity}              # agent or cop entity (zero_entity if empty)
    neighborhoods::Array{Vector{Tuple{Int,Int}}, 2}  # cached
end

function REBGrid(w::Int, h::Int, vision::Float64)
    cells = fill(zero_entity, w, h)
    neighborhoods = Array{Vector{Tuple{Int,Int}}}(undef, w, h)
    v = floor(Int, vision)
    for x in 1:w, y in 1:h
        nb = Tuple{Int,Int}[]
        for dx in -v:v, dy in -v:v
            (dx == 0 && dy == 0) && continue
            if sqrt(dx^2 + dy^2) <= vision
                nx = mod1(x + dx, w)
                ny = mod1(y + dy, h)
                push!(nb, (nx, ny))
            end
        end
        neighborhoods[x, y] = nb
    end
    REBGrid(w, h, cells, neighborhoods)
end

mutable struct REBStats
    num_quiet::Int
    num_active::Int
    num_jailed::Int
end
REBStats() = REBStats(0, 0, 0)
