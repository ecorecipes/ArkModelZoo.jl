# Crop IDs: 0=fallow, 1=beet, 2=buckwheat, 3=carrot, 4=cucurbit, 5=grass,
#            6=legume, 7=lettuce, 8=lily, 9=mustard, 10=nightshade, 11=rose,
#            12=cover_crop
const CR_FALLOW = 0
const CR_COVER = 12
const CR_NUM_CROPS = 13  # 0..12

# Crop properties stored in a struct for efficient lookup
struct CRCropInfo
    name::String
    nitrogen_req::Float64
    weed_suscept::Float64
    disease_suscept::Float64
    harvest_weeks::Int        # weeks until harvest
    nitrogen_fix::Float64     # nitrogen added after harvest (legumes add nitrogen)
end

function _cr_build_crop_table()
    # Properties: name, nitrogen_req, weed_suscept, disease_suscept, harvest_weeks, nitrogen_fix
    crops = CRCropInfo[
        CRCropInfo("fallow",     0.0, 0.0, 0.0, 8,  1.0),  # 0: fallow restores some nitrogen
        CRCropInfo("beet",       3.0, 0.6, 0.4, 16, 0.0),  # 1
        CRCropInfo("buckwheat",  2.0, 0.3, 0.2, 10, 0.0),  # 2
        CRCropInfo("carrot",     3.0, 0.5, 0.5, 14, 0.0),  # 3
        CRCropInfo("cucurbit",   4.0, 0.4, 0.6, 18, 0.0),  # 4
        CRCropInfo("grass",      1.0, 0.2, 0.1,  6, 0.5),  # 5
        CRCropInfo("legume",     1.0, 0.3, 0.3, 12, 3.0),  # 6: fixes nitrogen
        CRCropInfo("lettuce",    2.0, 0.7, 0.3, 8,  0.0),  # 7
        CRCropInfo("lily",       3.0, 0.4, 0.5, 14, 0.0),  # 8
        CRCropInfo("mustard",    2.0, 0.3, 0.4, 10, 1.0),  # 9: cover-like
        CRCropInfo("nightshade", 4.0, 0.5, 0.7, 16, 0.0),  # 10
        CRCropInfo("rose",       3.0, 0.4, 0.4, 14, 0.0),  # 11
        CRCropInfo("cover_crop", 0.5, 0.1, 0.1, 8,  2.0),  # 12: cover crop
    ]
    return crops
end

mutable struct CRState
    width::Int
    height::Int
    n_patches::Int
    crop_table::Vector{CRCropInfo}
    nitrogen::Vector{Float64}
    current_crop::Vector{Int}        # crop ID (0-12)
    previous_crop::Vector{Int}
    harvest_week::Vector{Int}        # tick when harvest/plant occurs
    last_yield::Vector{Float64}
    crop_history::Vector{Vector{Int}} # history of planted crops
    available_crops::Vector{Set{Int}} # crops still available (not removed by disease/weeds)
end

function CRState(w::Int, h::Int)
    n = w * h
    crop_table = _cr_build_crop_table()
    CRState(
        w, h, n,
        crop_table,
        zeros(Float64, n),
        fill(CR_FALLOW, n),
        fill(CR_FALLOW, n),
        zeros(Int, n),
        ones(Float64, n),
        [Int[] for _ in 1:n],
        [Set(1:12) for _ in 1:n],  # all non-fallow crops available initially
    )
end

mutable struct CRStats
    n_active_crops::Int  # patches with non-fallow crops
end
CRStats() = CRStats(0)
