module ArkModelZoo

using Ark
using Random
using Statistics

# The scheduler's `step!` is SciML's (CommonSolve's) `step!`, so that ArkModelZoo's
# `step!(scheduler)` and the integrator interface (`step!(integ, dt, true)`) share one function.
import SciMLBase
import SciMLBase: step!
using SciMLBase: init, solve, solve!, reinit!, remake, set_u!, terminate!, derivative_discontinuity!,
                 EnsembleProblem, EnsembleSerial, EnsembleThreads, ReturnCode
using DynamicalResilience: recovery, basin_stability, ramped_series, early_warning

# Extension modules
include("ext/rnd.jl")
include("ext/nw.jl")
include("ext/gis.jl")

# Export extension types and functions
export weighted_one_of, weighted_n_of, weighted_n_of_with_repeats
export NwGraph, nw_add_node!, nw_add_edge!, nw_remove_edge!, nw_has_edge, nw_degree, nw_neighbors
export nw_generate_preferential_attachment, nw_generate_random, nw_generate_watts_strogatz
export nw_generate_ring, nw_generate_lattice2d
export nw_bfs_distances, nw_mean_path_length
export nw_betweenness_centrality, nw_eigenvector_centrality, nw_page_rank, nw_closeness_centrality
export nw_clustering_coefficient, nw_mean_clustering_coefficient
export nw_connected_components, nw_louvain_communities, nw_label_propagation, nw_modularity
export nw_maximal_cliques
export GisEnvelope, GisRasterDataset, GisVectorFeature, GisVectorDataset, GisTransform
export gis_load_asc, gis_load_shapefile, gis_load_dataset
export gis_create_raster, gis_raster_value, gis_set_raster_value!
export gis_width, gis_height, gis_envelope, gis_minimum, gis_maximum, gis_mean
export gis_set_world_envelope, gis_to_netlogo, netlogo_to_gis
export gis_apply_raster, gis_apply_raster_simple, gis_raster_sample
export gis_convolve, SOBEL_X, SOBEL_Y
export gis_property_value, gis_centroid, gis_location

# Common infrastructure
include("common/resources.jl")
include("common/scheduler.jl")
include("common/model_registry.jl")
include("common/utils.jl")

for spec in MODEL_SPECS
    for filename in MODEL_FILE_ORDER
        include(joinpath(spec.directory, filename))
    end
end

export System,
       Scheduler,
       Tick,
       Terminate,
       RNGResource,
       initialize!,
       update!,
       finalize!,
       step!,
       run!,
       available_models,
       ModelSpec,
       model_categories,
       model_catalog,
       model_info,
       run_model

for spec in MODEL_SPECS
    @eval export $(spec.exports...)
end

# SciML problems and integrators for simulation-based resilience
include("sciml/problems.jl")
include("sciml/daisyworld.jl")
include("sciml/wolfsheep.jl")

export AbstractArkProblem, DaisyworldProblem, WolfSheepProblem, TickStepping, ArkIntegrator, ArkSolution,
       seed_trajectory
export init, solve, solve!, reinit!, remake, set_u!, terminate!, derivative_discontinuity!,
       EnsembleProblem, EnsembleSerial, EnsembleThreads
export recovery, basin_stability, ramped_series, early_warning

end
