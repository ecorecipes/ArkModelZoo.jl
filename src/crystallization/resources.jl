mutable struct CrystGrid
    metal_size::Int  # 31 (the metal block is metal_size x metal_size)
    temp::Matrix{Float64}
    heading::Matrix{Float64}
    neighbor_count::Matrix{Int}  # precomputed: number of metal neighbors (Moore, excluding self)
    sides_exposed::Matrix{Int}   # precomputed: 8 - neighbor_count
end

function CrystGrid(metal_size::Int)
    n = metal_size
    temp = zeros(Float64, n, n)
    heading = zeros(Float64, n, n)
    nc = zeros(Int, n, n)
    se = zeros(Int, n, n)
    # Precompute neighbor counts
    for x in 1:n, y in 1:n
        count = 0
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx, ny = x + dx, y + dy
            if 1 <= nx <= n && 1 <= ny <= n
                count += 1
            end
        end
        nc[x, y] = count
        se[x, y] = 8 - count
    end
    CrystGrid(n, temp, heading, nc, se)
end

mutable struct CrystStats
    ave_metal_temp::Float64
    num_frozen::Int
end
CrystStats() = CrystStats(0.0, 0)
