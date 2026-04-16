# ArkModelZoo.jl

A collection of classic agent-based models ported from [NetLogo](https://ccl.northwestern.edu/netlogo/) to Julia using the [Ark.jl](https://github.com/Ark-jl/Ark.jl) Entity Component System (ECS) framework.

## Models

| Model | Origin | Pattern | Description |
|-------|--------|---------|-------------|
| **Segregation** | Schelling (1971) | Spatial preference | Agents move until local neighborhood meets similarity threshold |
| **Wolf-Sheep Predation** | Wilensky (1997) | Multi-breed predator-prey | Wolves eat sheep, sheep eat grass, with energy and reproduction |
| **Ants** | Wilensky (1997) | Stigmergy / pheromone trails | Ants forage for food using chemical trail communication |
| **Daisyworld** | Watson & Lovelock (1983) | Ecology feedback | Black and white daisies regulate planetary temperature |
| **Virus** | Wilensky (1998) | Spatial epidemiology | SIR disease model with movement, aging, and reproduction |
| **Ethnocentrism** | Hammond & Axelrod (2006) | Evolutionary game theory | In-group/out-group cooperation strategies evolve via selection |

## Quick Start

```julia
using ArkModelZoo

# Run Schelling's Segregation model
scheduler, trajectory = run_segregation(
    params = SegregationParams(density=80.0, pct_similar_wanted=30.0)
)

# Run Wolf-Sheep Predation
scheduler, trajectory = run_wolfsheep(
    params = WolfSheepParams(initial_number_sheep=100, initial_number_wolves=50)
)

# Run Ants
scheduler, trajectory = run_ants(params = AntsParams(population=125))

# Run Daisyworld
scheduler, trajectory = run_daisyworld(params = DaisyworldParams(solar_luminosity=0.8))

# Run Virus (SIR with movement)
scheduler, trajectory = run_virus(params = VirusParams(number_people=200, virus_spread_chance=0.15))

# Run Ethnocentrism
scheduler, trajectory = run_ethnocentrism(params = EthnocentrismParams(max_ticks=2000))
```

To see the full catalog of available model entry points:

```julia
using ArkModelZoo

available_models()
```

For richer discovery metadata:

```julia
using ArkModelZoo

model_categories()
model_catalog(category="Biology & Ecology")
model_info("run_rgw")
model_info("simple_birth_rates")
run_model("simple_birth_rates"; params = BirthRatesParams(max_ticks=25))
```

You can also inspect the exported run functions directly:

```julia
sort(filter(name -> startswith(String(name), "run_"), names(ArkModelZoo)))
```

NetLogo-style wrapper spellings such as `simple_birth_rates`,
`disinfo_nw_bitstring`, `artificial_economy`, and `search_path` resolve through
`model_info` and the generic `run_model` entry point.

## ECS Architecture

Each model follows the same ECS pattern:

- **Components**: Lightweight mutable structs attached to entities (position, energy, health state, etc.)
- **Resources**: Global singleton state (grids, statistics, parameters, RNG)
- **Systems**: Ordered pipeline of update functions (`initialize!`, `update!`, `finalize!`)
- **Scheduler**: Runs systems in deterministic order, manages tick counter and termination

```
World ─┬─ Components (per-entity data)
       ├─ Resources (global state)
       └─ Systems (ordered update pipeline)
```

## Installation

```julia
using Pkg

# Install from a checkout
Pkg.develop(path="path/to/ArkModelZoo.jl")

# Or install directly from GitHub
Pkg.add(url="https://github.com/sdwfrost/ArkModelZoo.jl")
```

Requires `Ark.jl` v0.4+.

## Optional Dependencies

- **Shapefile-backed GIS models** such as `run_diffusionofhiv` require `Shapefile.jl`:

  ```julia
  using Pkg
  Pkg.add("Shapefile")
  ```

- **Vignette plot pre-rendering** uses the separate `vignettes/` environment:

  ```julia
  julia --project=vignettes -e 'using Pkg; Pkg.instantiate()'
  julia --project=vignettes vignettes/prerender.jl
  ```

## Testing

```julia
using Pkg
Pkg.test("ArkModelZoo")
```

Some GIS fixture tests depend on external NetLogo ClassModels data. Set
`NETLOGO_CLASSMODELS_DIR` to enable those tests in addition to the default suite.

GitHub Actions includes:

- `.github/workflows/ci.yml` for the portable default suite
- `.github/workflows/external-validation.yml` for manual GIS fixture and NetLogo calibration runs on a runner that already has the required paths available
