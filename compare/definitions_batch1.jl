# ── Model definitions batch 1 ────────────────────────────────────────
# Seven define_XXX() functions following the same pattern as
# define_segregation() / define_wolfsheep() / define_ants() in compare.jl.

function define_fire()
    code = """
globals [randomSeed density initial-trees burned-trees]

breed [fires fire]
breed [embers ember]

to setup
  clear-all
  resize-world (- 125) 125 (- 125) 125
  set density 57
  set-default-shape turtles "square"
  ask patches with [(random-float 100) < density]
    [ set pcolor green ]
  ask patches with [pxcor = min-pxcor]
    [ ignite ]
  set initial-trees count patches with [pcolor = green]
  set burned-trees 0
  reset-ticks
end

to go
  if not any? turtles [ stop ]
  ask fires
    [ ask neighbors4 with [pcolor = green]
        [ ignite ]
      set breed embers ]
  fade-embers
  tick
end

to ignite
  sprout-fires 1 [ set color red ]
  set pcolor black
  set burned-trees burned-trees + 1
end

to fade-embers
  ask embers
    [ set color color - 0.3
      if color < red - 3.5
        [ set pcolor color
          die ] ]
end
"""
    globals = ["initial-trees", "burned-trees"]
    nticks = 200
    dims = (-125, 125, -125, 125)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = FireParams(
                density=57.0, grid_width=251, grid_height=251,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_fire(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "initial-trees" => Float64[v[1] for v in trajectory],
                "burned-trees"  => Float64[v[2] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims, wrapping=(false, false))
    ("Forest Fire", nlogo_src, nticks, globals, ark_runner)
end

function define_voter()
    code = """
globals [randomSeed N pcolors n-colors]

to setup
  clear-all
  set N count patches
  set pcolors sublist (list grey white red yellow green orange blue pink) 0 2
  ask patches [
    set pcolor one-of pcolors
  ]
  set n-colors length remove-duplicates [pcolor] of patches
  reset-ticks
end

to go
  if length remove-duplicates [pcolor] of patches = 1 [ stop ]
  repeat count patches [
    ask one-of patches [
      set pcolor [pcolor] of one-of neighbors4
    ]
  ]
  set n-colors length remove-duplicates [pcolor] of patches
  tick
end
"""
    globals = ["n-colors"]
    nticks = 200
    dims = (0, 49, 0, 49)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = VoterParams(
                grid_width=50, grid_height=50,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_voter(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "n-colors" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Voter Model", nlogo_src, nticks, globals, ark_runner)
end

function define_ising()
    code = """
globals [randomSeed probability-of-spin-up temperature sum-of-spins]

patches-own [spin]

to setup
  clear-all
  resize-world (- 20) 20 (- 20) 20
  set probability-of-spin-up 50
  set temperature 2.27
  ask patches [
    ifelse random 100 < probability-of-spin-up
      [ set spin  1 ]
      [ set spin -1 ]
    recolor
  ]
  set sum-of-spins sum [ spin ] of patches
  reset-ticks
end

to go
  repeat 1000 [
    ask one-of patches [ update-spin ]
  ]
  tick
end

to update-spin
  let Ediff 2 * spin * sum [ spin ] of neighbors4
  if (Ediff <= 0) or (temperature > 0 and (random-float 1.0 < exp ((- Ediff) / temperature))) [
    set spin (- spin)
    set sum-of-spins sum-of-spins + 2 * spin
    recolor
  ]
end

to recolor
  ifelse spin = 1
    [ set pcolor blue + 2 ]
    [ set pcolor blue - 2 ]
end
"""
    globals = ["sum-of-spins"]
    nticks = 50
    dims = (-20, 20, -20, 20)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = IsingParams(
                probability_of_spin_up=50, temperature=2.27,
                grid_width=41, grid_height=41,
                updates_per_tick=1000, max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_ising(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "sum-of-spins" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Ising", nlogo_src, nticks, globals, ark_runner)
end

function define_decay()
    code = """
globals [randomSeed decay-chance number-nuclei decays last-count]

to setup
  clear-all
  resize-world (- 45) 45 (- 45) 45
  set decay-chance 3
  set number-nuclei 2500
  set-default-shape turtles "circle"
  ask n-of number-nuclei patches [
    sprout 1 [ set color cyan ]
  ]
  set last-count number-nuclei
  set decays 0
  reset-ticks
end

to go
  if all? turtles [color = blue - 3] [ stop ]
  set decays 0
  ask turtles with [color = cyan] [
    if random-float 100.0 < decay-chance [
      set color yellow
      set decays decays + 1
    ]
  ]
  ask turtles with [color = yellow] [ set color blue - 3 ]
  tick
end
"""
    globals = ["decays"]
    nticks = 200
    dims = (-45, 45, -45, 45)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = DecayParams(
                decay_chance=3.0, number_nuclei=2500,
                grid_width=91, grid_height=91,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_decay(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "decays" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Radioactive Decay", nlogo_src, nticks, globals, ark_runner)
end

function define_dla()
    code = """
globals [randomSeed wiggle-angle num-particles n-remaining]

to setup
  clear-all
  set wiggle-angle 60
  set num-particles 2500
  ask patch 0 0
    [ set pcolor green ]
  create-turtles num-particles
    [ set color red
      set size 1.5
      setxy random-xcor random-ycor ]
  set n-remaining count turtles
  reset-ticks
end

to go
  ask turtles
    [ right random wiggle-angle
      left random wiggle-angle
      forward 1
      if any? neighbors with [pcolor = green]
        [ set pcolor green
          die ] ]
  set n-remaining count turtles
  tick
end
"""
    globals = ["n-remaining"]
    nticks = 200
    dims = (-100, 100, -100, 100)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = DLAParams(
                wiggle_angle=60, num_particles=2500,
                grid_width=201, grid_height=201,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_dla(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "n-remaining" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("DLA Simple", nlogo_src, nticks, globals, ark_runner)
end

function define_contactprocess()
    code = """
globals [randomSeed N p-occupied initial-pop p-death]

to setup
  clear-all
  set initial-pop 1800
  set p-death 0.607
  set N count patches
  ask patches [
    ifelse random N < initial-pop
    [ set pcolor black ]
    [ set pcolor white ]
  ]
  set p-occupied count patches with [pcolor = black] / N
  reset-ticks
end

to go
  if not any? patches with [pcolor = black] [ stop ]
  repeat N [
    ask one-of patches [
      ifelse pcolor = black
      [ death-event ]
      [ birth-event ]
    ]
  ]
  set p-occupied count patches with [pcolor = black] / N
  tick
end

to death-event
  if random-float 1 < p-death [
    set pcolor white
  ]
end

to birth-event
  set pcolor [pcolor] of one-of neighbors4
end
"""
    globals = ["p-occupied"]
    nticks = 200
    dims = (-25, 24, -25, 24)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = ContactProcessParams(
                initial_pop=1800, p_death=0.607,
                grid_width=50, grid_height=50,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_contactprocess(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "p-occupied" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Contact Process 2D", nlogo_src, nticks, globals, ark_runner)
end

function define_flocking()
    code = """
globals [randomSeed population max-align-turn max-cohere-turn max-separate-turn vision minimum-separation avg-heading]

turtles-own [
  flockmates
  nearest-neighbor
]

to setup
  clear-all
  set population 200
  set max-align-turn 5
  set max-cohere-turn 3
  set max-separate-turn 1.5
  set vision 3
  set minimum-separation 1
  crt population
    [ set color yellow - 2 + random 7
      set size 1.5
      setxy random-xcor random-ycor ]
  reset-ticks
end

to go
  ask turtles [ flock ]
  repeat 5 [ ask turtles [ fd 0.2 ] ]
  set avg-heading mean [heading] of turtles
  tick
end

to flock
  find-flockmates
  if any? flockmates
    [ find-nearest-neighbor
      ifelse distance nearest-neighbor < minimum-separation
        [ separate ]
        [ align
          cohere ] ]
end

to find-flockmates
  set flockmates other turtles in-radius vision
end

to find-nearest-neighbor
  set nearest-neighbor min-one-of flockmates [distance myself]
end

to separate
  turn-away ([heading] of nearest-neighbor) max-separate-turn
end

to align
  turn-towards average-flockmate-heading max-align-turn
end

to-report average-flockmate-heading
  report atan sum [dx] of flockmates
              sum [dy] of flockmates
end

to cohere
  turn-towards average-heading-towards-flockmates max-cohere-turn
end

to-report average-heading-towards-flockmates
  report atan mean [sin (towards myself + 180)] of flockmates
              mean [cos (towards myself + 180)] of flockmates
end

to turn-towards [new-heading max-turn]
  turn-at-most (subtract-headings new-heading heading) max-turn
end

to turn-away [new-heading max-turn]
  turn-at-most (subtract-headings heading new-heading) max-turn
end

to turn-at-most [turn max-turn]
  ifelse abs turn > max-turn
    [ ifelse turn > 0
        [ rt max-turn ]
        [ lt max-turn ] ]
    [ rt turn ]
end
"""
    globals = ["avg-heading"]
    nticks = 200
    dims = (-45, 45, -45, 45)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = FlockingParams(
                population=200, max_align_turn=5.0,
                max_cohere_turn=3.0, max_separate_turn=1.5,
                vision=3.0, minimum_separation=1.0,
                grid_width=91, grid_height=91,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_flocking(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "avg-heading" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Flocking", nlogo_src, nticks, globals, ark_runner)
end
