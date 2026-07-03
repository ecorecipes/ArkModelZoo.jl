# GIS raster/vector data operations (NetLogo gis extension equivalent)

# ─── Raster Data ──────────────────────────────────────────────────────

"""
    GisEnvelope(xmin, xmax, ymin, ymax)

Bounding box for GIS data.
"""
struct GisEnvelope
    xmin::Float64
    xmax::Float64
    ymin::Float64
    ymax::Float64
end

"""
    GisRasterDataset

Raster grid data with geospatial metadata.
"""
mutable struct GisRasterDataset
    data::Matrix{Float64}   # row-major: data[row, col]
    width::Int               # ncols
    height::Int              # nrows
    envelope::GisEnvelope
    nodata::Float64
    cellsize_x::Float64
    cellsize_y::Float64
end

function Base.show(io::IO, r::GisRasterDataset)
    print(io, "GisRasterDataset($(r.width)×$(r.height), envelope=$(r.envelope.xmin)..$(r.envelope.xmax), $(r.envelope.ymin)..$(r.envelope.ymax))")
end

"""
    gis_load_asc(filepath) -> GisRasterDataset

Load an ESRI ASCII grid (.asc) file.
"""
function gis_load_asc(filepath::String)
    lines = readlines(filepath)
    header = Dict{String, String}()
    data_start = 1
    for (i, line) in enumerate(lines)
        parts = split(strip(line))
        if length(parts) == 2 && !all(c -> c in "0123456789.-eE+ ", line)
            header[lowercase(parts[1])] = parts[2]
            data_start = i + 1
        else
            break
        end
    end
    ncols = parse(Int, header["ncols"])
    nrows = parse(Int, header["nrows"])
    xll = parse(Float64, get(header, "xllcorner", get(header, "xllcenter", "0")))
    yll = parse(Float64, get(header, "yllcorner", get(header, "yllcenter", "0")))
    cellsize = parse(Float64, get(header, "cellsize", "1"))
    nodata = parse(Float64, get(header, "nodata_value", "-9999"))

    # Check for separate cellsizex/cellsizey
    cellsize_x = haskey(header, "cellsizex") ? parse(Float64, header["cellsizex"]) : cellsize
    cellsize_y = haskey(header, "cellsizey") ? parse(Float64, header["cellsizey"]) : cellsize

    data = Matrix{Float64}(undef, nrows, ncols)
    row = 1
    for i in data_start:length(lines)
        vals = split(strip(lines[i]))
        isempty(vals) && continue
        for (j, v) in enumerate(vals)
            if j <= ncols && row <= nrows
                data[row, j] = parse(Float64, v)
            end
        end
        row += 1
        row > nrows && break
    end

    # Envelope: xll is bottom-left corner
    xmin = xll
    ymin = yll
    xmax = xll + ncols * cellsize_x
    ymax = yll + nrows * cellsize_y

    return GisRasterDataset(data, ncols, nrows,
        GisEnvelope(xmin, xmax, ymin, ymax),
        nodata, cellsize_x, cellsize_y)
end

"""
    gis_create_raster(width, height, envelope) -> GisRasterDataset

Create an empty raster with given dimensions and envelope.
"""
function gis_create_raster(width::Int, height::Int, envelope::GisEnvelope)
    data = zeros(height, width)
    cellsize_x = (envelope.xmax - envelope.xmin) / width
    cellsize_y = (envelope.ymax - envelope.ymin) / height
    return GisRasterDataset(data, width, height, envelope, -9999.0, cellsize_x, cellsize_y)
end

"""
    gis_raster_value(raster, col, row) -> Float64

Get value at (col, row) — 0-indexed like NetLogo.
"""
function gis_raster_value(raster::GisRasterDataset, col::Int, row::Int)
    # NetLogo uses 0-indexed, row 0 = top
    return raster.data[row + 1, col + 1]
end

"""
    gis_set_raster_value!(raster, col, row, value)

Set value at (col, row) — 0-indexed.
"""
function gis_set_raster_value!(raster::GisRasterDataset, col::Int, row::Int, value::Float64)
    raster.data[row + 1, col + 1] = value
end

gis_width(raster::GisRasterDataset) = raster.width
gis_height(raster::GisRasterDataset) = raster.height
gis_envelope(raster::GisRasterDataset) = raster.envelope

function gis_minimum(raster::GisRasterDataset)
    vals = filter(v -> v != raster.nodata, vec(raster.data))
    return isempty(vals) ? raster.nodata : minimum(vals)
end

function gis_maximum(raster::GisRasterDataset)
    vals = filter(v -> v != raster.nodata, vec(raster.data))
    return isempty(vals) ? raster.nodata : maximum(vals)
end

function gis_mean(raster::GisRasterDataset)
    vals = filter(v -> v != raster.nodata, vec(raster.data))
    return isempty(vals) ? 0.0 : sum(vals) / length(vals)
end

# ─── Coordinate Transformation ────────────────────────────────────────

"""
    GisTransform(gis_envelope, nl_xmin, nl_xmax, nl_ymin, nl_ymax)

Affine transformation between GIS coordinates and NetLogo grid coordinates.
"""
struct GisTransform
    gis_env::GisEnvelope
    nl_xmin::Float64
    nl_xmax::Float64
    nl_ymin::Float64
    nl_ymax::Float64
    # Computed scale/offset
    scale_x::Float64
    scale_y::Float64
    offset_x::Float64
    offset_y::Float64
end

function GisTransform(gis_env::GisEnvelope, nl_xmin, nl_xmax, nl_ymin, nl_ymax)
    gis_w = gis_env.xmax - gis_env.xmin
    gis_h = gis_env.ymax - gis_env.ymin
    nl_w = nl_xmax - nl_xmin
    nl_h = nl_ymax - nl_ymin
    scale_x = gis_w > 0 ? nl_w / gis_w : 1.0
    scale_y = gis_h > 0 ? nl_h / gis_h : 1.0
    offset_x = nl_xmin - gis_env.xmin * scale_x
    offset_y = nl_ymin - gis_env.ymin * scale_y
    return GisTransform(gis_env, Float64(nl_xmin), Float64(nl_xmax),
                        Float64(nl_ymin), Float64(nl_ymax),
                        scale_x, scale_y, offset_x, offset_y)
end

"""
    gis_to_netlogo(transform, gis_x, gis_y) -> (nl_x, nl_y)
"""
function gis_to_netlogo(t::GisTransform, gis_x::Float64, gis_y::Float64)
    nl_x = gis_x * t.scale_x + t.offset_x
    nl_y = gis_y * t.scale_y + t.offset_y
    return (nl_x, nl_y)
end

"""
    netlogo_to_gis(transform, nl_x, nl_y) -> (gis_x, gis_y)
"""
function netlogo_to_gis(t::GisTransform, nl_x::Float64, nl_y::Float64)
    gis_x = (nl_x - t.offset_x) / t.scale_x
    gis_y = (nl_y - t.offset_y) / t.scale_y
    return (gis_x, gis_y)
end

# ─── Apply Raster to Grid ────────────────────────────────────────────

"""
    gis_apply_raster(raster, grid_width, grid_height, transform) -> Matrix{Float64}

Map raster values onto a NetLogo-style patch grid.
Returns a matrix indexed [x, y] where x=1..grid_width, y=1..grid_height.
Uses nearest-neighbor sampling.
"""
function gis_apply_raster(raster::GisRasterDataset, grid_width::Int, grid_height::Int, transform::GisTransform)
    result = fill(raster.nodata, grid_width, grid_height)
    for gx in 1:grid_width, gy in 1:grid_height
        # Grid center in NetLogo coords (assuming patch (gx,gy) → center (gx-0.5, gy-0.5) offset)
        nl_x = transform.nl_xmin + (gx - 0.5) * (transform.nl_xmax - transform.nl_xmin) / grid_width
        nl_y = transform.nl_ymin + (gy - 0.5) * (transform.nl_ymax - transform.nl_ymin) / grid_height
        # Convert to GIS coords
        gis_x, gis_y = netlogo_to_gis(transform, nl_x, nl_y)
        # Map to raster cell (nearest neighbor)
        col = floor(Int, (gis_x - raster.envelope.xmin) / raster.cellsize_x)
        row = floor(Int, (raster.envelope.ymax - gis_y) / raster.cellsize_y)  # y is flipped
        if 0 <= col < raster.width && 0 <= row < raster.height
            result[gx, gy] = raster.data[row + 1, col + 1]
        end
    end
    return result
end

"""
    gis_apply_raster_simple(raster) -> Matrix{Float64}

Simplified raster application: directly map raster data to a grid of the same dimensions.
Returns matrix[x, y] where x=1..width, y=1..height.
Row 0 in raster = top = y=height in grid (flipped y-axis).
"""
function gis_apply_raster_simple(raster::GisRasterDataset)
    result = Matrix{Float64}(undef, raster.width, raster.height)
    for row in 1:raster.height, col in 1:raster.width
        # Raster row 1 = top = grid y=height, raster row H = bottom = grid y=1
        result[col, raster.height - row + 1] = raster.data[row, col]
    end
    return result
end

"""
    gis_raster_sample(raster, gis_x, gis_y; method=:nearest) -> Float64

Sample raster at GIS coordinates. Methods: :nearest, :bilinear.
"""
function gis_raster_sample(raster::GisRasterDataset, gis_x::Float64, gis_y::Float64; method::Symbol=:nearest)
    col_f = (gis_x - raster.envelope.xmin) / raster.cellsize_x
    row_f = (raster.envelope.ymax - gis_y) / raster.cellsize_y

    if method == :nearest
        col = clamp(round(Int, col_f), 1, raster.width)
        row = clamp(round(Int, row_f), 1, raster.height)
        return raster.data[row, col]
    elseif method == :bilinear
        c0 = clamp(floor(Int, col_f), 1, raster.width)
        c1 = clamp(c0 + 1, 1, raster.width)
        r0 = clamp(floor(Int, row_f), 1, raster.height)
        r1 = clamp(r0 + 1, 1, raster.height)
        fx = col_f - floor(col_f)
        fy = row_f - floor(row_f)
        v00 = raster.data[r0, c0]; v01 = raster.data[r0, c1]
        v10 = raster.data[r1, c0]; v11 = raster.data[r1, c1]
        return v00 * (1 - fx) * (1 - fy) + v01 * fx * (1 - fy) +
               v10 * (1 - fx) * fy + v11 * fx * fy
    else
        error("Unknown sampling method: $method")
    end
end

# ─── Convolution ──────────────────────────────────────────────────────

"""
    gis_convolve(raster, kernel) -> GisRasterDataset

2D convolution with edge reflection. Returns a new raster.
"""
function gis_convolve(raster::GisRasterDataset, kernel::Matrix{Float64})
    kh, kw = size(kernel)
    hh, hw = div(kh, 2), div(kw, 2)
    result = copy(raster.data)
    for row in 1:raster.height, col in 1:raster.width
        val = 0.0
        for kr in 1:kh, kc in 1:kw
            sr = row + kr - hh - 1
            sc = col + kc - hw - 1
            # Reflect at boundaries
            sr = sr < 1 ? 2 - sr : (sr > raster.height ? 2 * raster.height - sr : sr)
            sc = sc < 1 ? 2 - sc : (sc > raster.width ? 2 * raster.width - sc : sc)
            sr = clamp(sr, 1, raster.height)
            sc = clamp(sc, 1, raster.width)
            val += raster.data[sr, sc] * kernel[kr, kc]
        end
        result[row, col] = val
    end
    return GisRasterDataset(result, raster.width, raster.height,
        raster.envelope, raster.nodata, raster.cellsize_x, raster.cellsize_y)
end

# Sobel gradient kernels
const SOBEL_X = Float64[-1 0 1; -2 0 2; -1 0 1]
const SOBEL_Y = Float64[-1 -2 -1; 0 0 0; 1 2 1]

# ─── Vector Data (Shapefile) ─────────────────────────────────────────

"""
    GisVectorFeature

A single feature from a vector dataset with geometry and properties.
"""
struct GisVectorFeature
    shape_type::Symbol           # :point, :line, :polygon
    points::Vector{Tuple{Float64, Float64}}  # vertices
    properties::Dict{String, Any}
    centroid::Tuple{Float64, Float64}
end

"""
    GisVectorDataset

Collection of vector features with metadata.
"""
struct GisVectorDataset
    features::Vector{GisVectorFeature}
    property_names::Vector{String}
    envelope::GisEnvelope
end

"""
    gis_load_shapefile(filepath) -> GisVectorDataset

Load a shapefile (.shp). Requires Shapefile.jl to be loaded.
Falls back to error if not available.
"""
function gis_load_shapefile(filepath::String)
    # Dynamic loading of Shapefile package
    shp_mod = try
        @eval Main begin
            import Shapefile
            Shapefile
        end
    catch
        error("Shapefile.jl is required to load shapefiles. Run: ] add Shapefile")
    end

    table = shp_mod.Table(filepath)
    rows = collect(table)
    colnames = string.(propertynames(first(rows)))
    # Filter out :geometry column name
    prop_names = filter(n -> n != "geometry", colnames)

    features = GisVectorFeature[]
    xmin, xmax, ymin, ymax = Inf, -Inf, Inf, -Inf

    for row in rows
        geom = row.geometry
        pts = Tuple{Float64, Float64}[]
        _extract_points!(pts, geom)

        if !isempty(pts)
            cx = sum(p[1] for p in pts) / length(pts)
            cy = sum(p[2] for p in pts) / length(pts)
            for (px, py) in pts
                xmin = min(xmin, px); xmax = max(xmax, px)
                ymin = min(ymin, py); ymax = max(ymax, py)
            end
        else
            cx, cy = 0.0, 0.0
        end

        props = Dict{String, Any}()
        for name in prop_names
            props[name] = getproperty(row, Symbol(name))
        end

        shape_type = if hasproperty(geom, :x) && hasproperty(geom, :y)
            :point
        elseif geom isa shp_mod.AbstractPolyline
            :line
        else
            :polygon
        end
        push!(features, GisVectorFeature(shape_type, pts, props, (cx, cy)))
    end

    env = GisEnvelope(xmin, xmax, ymin, ymax)
    return GisVectorDataset(features, prop_names, env)
end

function _extract_points!(pts::Vector{Tuple{Float64, Float64}}, geom)
    if hasproperty(geom, :points)
        for p in geom.points
            push!(pts, (Float64(p.x), Float64(p.y)))
        end
    elseif hasproperty(geom, :x) && hasproperty(geom, :y)
        push!(pts, (Float64(geom.x), Float64(geom.y)))
    end
end

"""
    gis_property_value(feature, name) -> Any
"""
gis_property_value(f::GisVectorFeature, name::String) = f.properties[name]

"""
    gis_centroid(feature) -> (x, y)
"""
gis_centroid(f::GisVectorFeature) = f.centroid

"""
    gis_location(feature, transform) -> (nl_x, nl_y)

Convert feature centroid to NetLogo grid coordinates.
"""
function gis_location(f::GisVectorFeature, transform::GisTransform)
    gis_to_netlogo(transform, f.centroid[1], f.centroid[2])
end

"""
    gis_load_dataset(filepath) -> Union{GisRasterDataset, GisVectorDataset}

Auto-detect and load .asc (raster) or .shp (vector) files.
"""
function gis_load_dataset(filepath::String)
    ext = lowercase(splitext(filepath)[2])
    if ext == ".asc"
        return gis_load_asc(filepath)
    elseif ext == ".shp"
        return gis_load_shapefile(filepath)
    else
        error("Unsupported GIS file format: $ext")
    end
end

"""
    gis_set_world_envelope(envelope, nl_xmin, nl_xmax, nl_ymin, nl_ymax) -> GisTransform

Create a coordinate transformation mapping GIS envelope to NetLogo world bounds.
"""
function gis_set_world_envelope(envelope::GisEnvelope, nl_xmin, nl_xmax, nl_ymin, nl_ymax)
    return GisTransform(envelope, nl_xmin, nl_xmax, nl_ymin, nl_ymax)
end
