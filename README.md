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
    params = SegregationParams(number=2000, pct_similar_wanted=30.0)
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
scheduler, trajectory = run_virus(params = VirusParams(infectiousness=65.0))

# Run Ethnocentrism
scheduler, trajectory = run_ethnocentrism(params = EthnocentrismParams(max_ticks=2000))
```

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
Pkg.develop(path="path/to/ArkModelZoo.jl")
```

Requires `Ark.jl` v0.4+.

## Testing

```julia
using Pkg
Pkg.test("ArkModelZoo")
```
