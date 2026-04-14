# ── Batch 2 model definitions for comparison harness ───────────────────
# Each function returns (name, nlogo_src, nticks, globals, ark_runner)

function define_sir()
    code = """
globals [randomSeed num-susceptible num-infected num-recovered]
turtles-own [state days-infected]

to setup
  clear-all
  create-turtles 200 [
    setxy random-xcor random-ycor
    set state "S"
    set days-infected 0
    set color green
  ]
  ask n-of 5 turtles [
    set state "I"
    set color red
    set days-infected 1
  ]
  update-counts
  reset-ticks
end

to go
  if num-infected = 0 [ stop ]
  ask turtles [
    rt random 50 - 25
    fd 1
  ]
  ask turtles with [state = "I"] [
    ask turtles in-radius 1.5 with [state = "S"] [
      if random-float 1.0 < 0.15 [
        set state "I"
        set color red
        set days-infected 1
      ]
    ]
    set days-infected days-infected + 1
    if days-infected > 14 [
      set state "R"
      set color gray
    ]
  ]
  update-counts
  tick
end

to update-counts
  set num-susceptible count turtles with [state = "S"]
  set num-infected count turtles with [state = "I"]
  set num-recovered count turtles with [state = "R"]
end
"""
    globals = ["num-susceptible", "num-infected", "num-recovered"]
    nticks = 200
    dims = (-16, 16, -16, 16)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = SIRParams(
                num_people=200, initial_infected=5,
                infection_radius=1.5, infection_chance=0.15,
                recovery_time=14,
                grid_width=33, grid_height=33,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_sir(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "num-susceptible" => Float64[v[1] for v in trajectory],
                "num-infected"    => Float64[v[2] for v in trajectory],
                "num-recovered"   => Float64[v[3] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("SIR", nlogo_src, nticks, globals, ark_runner)
end

function define_grassbrushtrees()
    code = """
globals [randomSeed N pcolors norm-b-1 norm-b-2 norm-d n-trees birth-rate-1 birth-rate-2]

patches-own [particle-type]

to setup
  clear-all
  set birth-rate-1 6
  set birth-rate-2 2
  set pcolors (list (lime + 2) (green - 1) (green - 3))
  set N count patches
  ask patches [
    set particle-type random 3
    set pcolor item particle-type pcolors
  ]
  set n-trees count patches with [particle-type = 2]
  reset-ticks
end

to go
  repeat N [
    let max-rate max (list birth-rate-1 birth-rate-2)
    set norm-d 1 / max-rate
    set norm-b-1 birth-rate-1 / max-rate
    set norm-b-2 birth-rate-2 / max-rate
    ask one-of patches [
      ifelse random 2 = 1
      [ death-event ]
      [ birth-event ]
    ]
  ]
  set n-trees count patches with [particle-type = 2]
  tick
end

to death-event
  if random-float 1 < norm-d [
    set particle-type 0
    set pcolor item particle-type pcolors
  ]
end

to birth-event
  if particle-type > 0 [
    ifelse particle-type = 1 [
      if random-float 1 < norm-b-1 [
        ask one-of neighbors4 [
          if particle-type = 0 [
            set particle-type 1
            set pcolor item particle-type pcolors
          ]
        ]
      ]
    ]
    [
      if random-float 1 < norm-b-2 [
        ask one-of neighbors4 [
          if particle-type < 2 [
            set particle-type 2
            set pcolor item particle-type pcolors
          ]
        ]
      ]
    ]
  ]
end
"""
    globals = ["n-trees"]
    nticks = 200
    dims = (0, 49, 0, 49)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = GBTParams(
                grid_width=50, grid_height=50,
                birth_rate_1=6.0, birth_rate_2=2.0,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_gbt(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "n-trees" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Grass Brush Trees", nlogo_src, nticks, globals, ark_runner)
end

function define_boiling()
    code = """
globals [randomSeed avg-heat]

patches-own [heat]

to setup
  clear-all
  ask patches [
    set heat random 212
    set pcolor scale-color red heat 0 212
  ]
  set avg-heat mean [heat] of patches
  reset-ticks
end

to go
  diffuse heat 1
  ask patches [
    set heat (heat + 5) mod 212
    set pcolor scale-color red heat 0 212
  ]
  set avg-heat mean [heat] of patches
  tick
end
"""
    globals = ["avg-heat"]
    nticks = 200
    dims = (-40, 40, -40, 40)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = BoilingParams(
                grid_width=81, grid_height=81,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_boiling(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "avg-heat" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Boiling", nlogo_src, nticks, globals, ark_runner)
end

function define_mousetraps()
    code = """
globals [randomSeed max-distance traps-triggered balls-in-air]

to setup
  clear-all
  __change-topology false false
  set max-distance 4.5
  set traps-triggered 0
  ask patches [ set pcolor blue + 3 ]
  set-default-shape turtles "circle"
  crt 1 [
    set color white
    set size 1.5
  ]
  set balls-in-air count turtles
  reset-ticks
end

to go
  if not any? turtles [ stop ]
  ask turtles [
    ifelse pcolor = red
      [ die ]
      [
        set pcolor red
        set traps-triggered traps-triggered + 1
        hatch 1 [ move ]
        move
      ]
  ]
  set balls-in-air count turtles
  tick
end

to move
  rt random-float 360
  fd random-float max-distance
end
"""
    globals = ["traps-triggered", "balls-in-air"]
    nticks = 150
    dims = (-80, 80, -80, 80)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = MousetrapParams(
                max_distance=4.5, half_width=80,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_mousetraps(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "traps-triggered" => Float64[v[1] for v in trajectory],
                "balls-in-air"    => Float64[v[2] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims, wrapping=(false, false))
    ("Mousetraps", nlogo_src, nticks, globals, ark_runner)
end

function define_birthrates()
    code = """
globals [randomSeed blue-fertility carrying-capacity red-fertility
         red-count blue-count]

turtles-own [fertility fertility-remainder]

to setup
  clear-all
  resize-world (- 25) 25 (- 25) 25
  set blue-fertility 2
  set carrying-capacity 200
  set red-fertility 2
  create-turtles carrying-capacity [
    setxy random-xcor random-ycor
    ifelse who < (carrying-capacity / 2)
      [ set color blue ]
      [ set color red ]
    set size 2
  ]
  update-counts
  reset-ticks
end

to go
  reproduce
  grim-reaper
  update-counts
  tick
end

to update-counts
  set red-count count turtles with [color = red]
  set blue-count count turtles with [color = blue]
end

to wander
  rt random-float 30 - random-float 30
  fd 1
end

to reproduce
  ask turtles [
    ifelse color = red [
      set fertility floor red-fertility
      set fertility-remainder red-fertility - (floor red-fertility)
    ] [
      set fertility floor blue-fertility
      set fertility-remainder blue-fertility - (floor blue-fertility)
    ]
    ifelse (random-float 100) < (100 * fertility-remainder)
      [ hatch fertility + 1 [ wander ] ]
      [ hatch fertility     [ wander ] ]
  ]
end

to grim-reaper
  let num-turtles count turtles
  if num-turtles <= carrying-capacity [ stop ]
  let chance-to-die (num-turtles - carrying-capacity) / num-turtles
  ask turtles [
    if random-float 1.0 < chance-to-die [ die ]
  ]
end
"""
    globals = ["red-count", "blue-count"]
    nticks = 50
    dims = (-25, 25, -25, 25)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = BirthRatesParams(
                carrying_capacity=200,
                red_fertility=2.0, blue_fertility=2.0,
                grid_width=51, grid_height=51,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_birthrates(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "red-count"  => Float64[v[1] for v in trajectory],
                "blue-count" => Float64[v[2] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Simple Birth Rates", nlogo_src, nticks, globals, ark_runner)
end

function define_diffusion()
    code = """
globals [randomSeed max-temp mean-temp]
patches-own [temp]

to setup
  clear-all
  ask patches [
    set temp 0
  ]
  ask patch 0 0 [
    set temp 100
    ask neighbors [ set temp 50 ]
  ]
  recolor
  update-stats
  reset-ticks
end

to go
  diffuse temp 0.5
  ask patches [
    set temp temp * 0.99
  ]
  ask patch 0 0 [ set temp 100 ]
  recolor
  update-stats
  tick
end

to recolor
  ask patches [
    set pcolor scale-color red temp 0 100
  ]
end

to update-stats
  set max-temp max [temp] of patches
  set mean-temp mean [temp] of patches
end
"""
    globals = ["max-temp", "mean-temp"]
    nticks = 100
    dims = (-16, 16, -16, 16)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = DiffusionParams(
                grid_width=33, grid_height=33,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_diffusion(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "max-temp"  => Float64[v[1] for v in trajectory],
                "mean-temp" => Float64[v[2] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Heat Diffusion", nlogo_src, nticks, globals, ark_runner)
end

function define_coordination()
    code = """
globals [randomSeed init-norm1 coordination-benefit n-norm1]
turtles-own [norm1? payoff]

to setup
  clear-all
  set init-norm1 0.5
  set coordination-benefit 1
  ask patches [
    sprout 1 [
      set shape "circle"
      ifelse random-float 1 < init-norm1 [set norm1? true] [set norm1? false]
    ]
  ]
  recolor
  set n-norm1 count turtles with [norm1?]
  reset-ticks
end

to go
  if (count turtles with [norm1?]) = (count turtles) or
     (count turtles with [norm1?]) = 0
    [stop]
  calculate-payoffs
  evolve
  recolor
  set n-norm1 count turtles with [norm1?]
  tick
end

to calculate-payoffs
  let p1 (count turtles with [norm1?]) / (count turtles)
  let norm1-payoff 1 + (p1 * coordination-benefit)
  let norm2-payoff 1 + ((1 - p1) * coordination-benefit)
  ask turtles with [norm1?] [set payoff norm1-payoff]
  ask turtles with [not norm1?] [set payoff norm2-payoff]
end

to evolve
  ask turtles [
    let model one-of other turtles
    if [norm1?] of model != [norm1?] of self [
      let other-payoff [payoff] of model
      let prob-copy (1 / (1 + exp (-1 * (other-payoff - payoff))))
      if random-float 1 < prob-copy
        [set norm1? [norm1?] of model]
    ]
  ]
end

to recolor
  ask turtles [
    ifelse norm1? [set color yellow] [set color blue]
  ]
end

to-report freq-norm1
  report (count turtles with [norm1?]) / (count turtles)
end
"""
    globals = ["n-norm1"]
    nticks = 200
    dims = (-16, 16, -16, 16)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = CoordinationParams(
                init_norm1=0.5, coordination_benefit=1.0,
                grid_size=33,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_coordination(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "n-norm1" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Coordination", nlogo_src, nticks, globals, ark_runner)
end
