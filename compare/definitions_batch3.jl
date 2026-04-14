# ── Batch 3 model definitions ─────────────────────────────────────────
# Seven additional models for the ArkModelZoo ↔ NetLogo comparison harness.
# Each define_XXX() returns (name, nlogo_src, nticks, globals, ark_runner).

# ── 1. Rope (deterministic wave propagation) ─────────────────────────

function define_rope()
    code = """
globals [randomSeed friction frequency amplitude n-visible]

turtles-own [
  yvel
  ypos
]

to setup
  clear-all
  __change-topology false false
  set friction 24
  set frequency 10
  set amplitude 30
  set-default-shape turtles "circle"
  create-turtles world-width [
    set xcor who
    set color red
    set size 1.5
    if pxcor = max-pxcor
      [ set color blue ]
    if pxcor = min-pxcor
      [ set color green ]
  ]
  reset-ticks
end

to go
  ask turtles with [color = green]
  [
    ifelse ticks > 100
       [ set ypos amplitude * sin (frequency * ticks) ]
       [ set ypos (ticks / 100) * amplitude * sin (frequency * ticks) ]
    ifelse patch-at 0 (ypos - ycor) != nobody
    [
      set ycor ypos
      show-turtle
    ]
    [ hide-turtle ]
  ]
  ask turtles with [color = red]
  [
    set yvel yvel + ((([ypos] of (turtle (who - 1))) - ypos) +
                     (([ypos] of (turtle (who + 1))) - ypos))
    set yvel ((1000 - friction) / 1000) * yvel
  ]
  ask turtles with [color = red]
  [
    set ypos ypos + yvel
    ifelse patch-at 0 (ypos - ycor) != nobody
      [ set ycor ypos
        show-turtle ]
      [ hide-turtle ]
  ]
  set n-visible count turtles with [not hidden?]
  tick
end
"""
    globals = ["n-visible"]
    nticks = 500
    dims = (0, 160, -80, 80)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = RopeParams(
                world_width=161, y_min=-80, y_max=80,
                friction=24, frequency=10, amplitude=30,
                max_ticks=nticks
            )
            scheduler, trajectory = run_rope(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "n-visible" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims, wrapping=(false, false))
    ("Rope", nlogo_src, nticks, globals, ark_runner)
end

# ── 2. Particles ─────────────────────────────────────────────────────

function define_particles()
    code = """
globals [randomSeed num-particles whimsy speed collisions]

to setup
  clear-all
  set num-particles 50
  set whimsy 0
  set speed 0.02
  set-default-shape turtles "default"
  create-turtles num-particles [
    set color green
    set size 2
    setxy random-xcor random-ycor
    set heading random 360
  ]
  set collisions 0
  reset-ticks
end

to go
  ask turtles [
    if whimsy > 0 [
      right random whimsy
      left random whimsy
    ]
    forward speed
    if count turtles in-radius 1 > 1 [
      ask turtles in-radius 1 [
        set heading random 360
        fd 0.1
      ]
      set collisions (collisions + 1)
    ]
  ]
  tick
end
"""
    globals = ["collisions"]
    nticks = 200
    dims = (-16, 16, -16, 16)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = ParticlesParams(
                num_particles=50, speed=0.02,
                collision_radius=1.0, collision_speed=0.1,
                grid_width=33, grid_height=33,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_particles(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "collisions" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Particles", nlogo_src, nticks, globals, ark_runner)
end

# ── 3. Contagion SI ──────────────────────────────────────────────────

function define_contagion_si()
    code = """
globals [randomSeed num-turtles init-infected speed turning-angle transmissibility spontaneous-infect n-infected]
turtles-own [infected?]

to setup
  clear-all
  set num-turtles 300
  set init-infected 3
  set speed 0.5
  set turning-angle 60
  set transmissibility 0.01
  set spontaneous-infect 0
  setup-turtles
  setup-infected
  recolor
  set n-infected count turtles with [infected?]
  reset-ticks
end

to setup-turtles
  create-turtles num-turtles [
    set shape "circle"
    set infected? false
    setxy random-xcor random-ycor
  ]
end

to setup-infected
  if init-infected > num-turtles [set init-infected 1]
  ask n-of init-infected turtles [set infected? true]
end

to recolor
  ask turtles [
    ifelse infected? [set color red] [set color white]
  ]
end

to go
  if (count turtles with [infected?]) = num-turtles [stop]
  infect-susceptibles
  recolor
  move
  set n-infected count turtles with [infected?]
  tick
end

to infect-susceptibles
  ask turtles with [not infected?] [
    let infected-neighbors (count other turtles with [color = red] in-radius 1)
    if random-float 1 < 1 - (((1 - transmissibility) ^ infected-neighbors) * (1 - spontaneous-infect))
      [set infected? true]
  ]
end

to move
  ask turtles [
    left random turning-angle
    right random turning-angle
    fd speed
  ]
end
"""
    globals = ["n-infected"]
    nticks = 200
    dims = (-16, 16, -16, 16)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = ContagionSIParams(
                num_turtles=300, init_infected=3,
                speed=0.5, turning_angle=60,
                transmissibility=0.01, spontaneous_infect=0.0,
                grid_width=33, grid_height=33,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_contagionsi(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "n-infected" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Contagion SI", nlogo_src, nticks, globals, ark_runner)
end

# ── 4. Fire Percolation ──────────────────────────────────────────────

function define_firepercolation()
    code = """
globals [randomSeed fire-front fire-size p]

to setup
  clear-all
  set p 0.6
  ask n-of (p * count patches) patches [set pcolor green]
  set fire-front patch-set nobody
  set fire-size 0
  reset-ticks
end

to go
  if ticks = 0 [
    ignite-fire
  ]
  ifelse any? fire-front [
    fire-spread
  ]
  [ stop ]
  set fire-size count patches with [pcolor = red]
  tick
end

to ignite-fire
  ask one-of patches with [pcolor = green] [
    set pcolor red
    set fire-front patch-set self
  ]
  set fire-size 1
end

to fire-spread
  let new-fire-front patch-set nobody
  ask fire-front [
    let n-green neighbors4 with [pcolor = green]
    ask n-green [
      set new-fire-front (patch-set new-fire-front self)
    ]
  ]
  ask new-fire-front [set pcolor red]
  set fire-front new-fire-front
end
"""
    globals = ["fire-size"]
    nticks = 100
    dims = (0, 99, 0, 99)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = FirePercolationParams(
                p=0.6, grid_width=100, grid_height=100,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_firepercolation(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "fire-size" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Fire Percolation", nlogo_src, nticks, globals, ark_runner)
end

# ── 5. Contagion SIR ─────────────────────────────────────────────────

function define_contagion_sir()
    code = """
globals [randomSeed num-turtles init-infected speed turning-angle transmissibility spontaneous-infect recovery-rate remove-recovered? n-infected n-immune]
turtles-own [infected? immune?]

to setup
  clear-all
  set num-turtles 500
  set init-infected 3
  set speed 1
  set turning-angle 360
  set transmissibility 0.1
  set spontaneous-infect 0
  set recovery-rate 0.01
  set remove-recovered? false
  setup-turtles
  setup-infected
  recolor
  set n-infected count turtles with [infected?]
  set n-immune count turtles with [immune?]
  reset-ticks
end

to setup-turtles
  create-turtles num-turtles [
    set shape "circle"
    set color white
    set infected? false
    set immune? false
    setxy random-xcor random-ycor
  ]
end

to setup-infected
  if init-infected > num-turtles [set init-infected 1]
  ask n-of init-infected turtles [set infected? true]
end

to recolor
  ask turtles [
    ifelse infected? [set color red]
      [ifelse immune? [set color grey] [set color white]]
  ]
end

to go
  infect-susceptibles
  recover-infecteds
  recolor
  move
  set n-infected count turtles with [infected?]
  set n-immune count turtles with [immune?]
  tick
end

to infect-susceptibles
  ask turtles with [not infected? and not immune?] [
    let infected-neighbors (count other turtles with [color = red] in-radius 1)
    if (random-float 1 < 1 - (((1 - transmissibility) ^ infected-neighbors) * (1 - spontaneous-infect)))
      [set infected? true]
  ]
end

to recover-infecteds
  ask turtles with [infected? and color = red] [
    if random-float 1 < recovery-rate [
      set infected? false
      if remove-recovered? [set immune? true]
    ]
  ]
end

to move
  ask turtles [
    left random turning-angle
    right random turning-angle
    fd speed
  ]
end

to-report prop-infected
  report (count turtles with [infected?]) / num-turtles
end
"""
    globals = ["n-infected", "n-immune"]
    nticks = 200
    dims = (-16, 16, -16, 16)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = ContagionSIRParams(
                num_turtles=500, init_infected=3,
                speed=1.0, turning_angle=360,
                transmissibility=0.1, spontaneous_infect=0.0,
                recovery_rate=0.01, remove_recovered=false,
                grid_width=33, grid_height=33,
                max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_contagionsir(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "n-infected" => Float64[v[1] for v in trajectory],
                "n-immune"   => Float64[v[2] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Contagion SIR", nlogo_src, nticks, globals, ark_runner)
end

# ── 6. COIN (Collective Intelligence) ────────────────────────────────

function define_coin()
    code = """
globals [
  randomSeed
  num-agents
  discount-rate
  current-utility
  attendance0 attendance1 attendance2 attendance3 attendance4 attendance5 attendance6
  reward0 reward1 reward2 reward3 reward4 reward5 reward6
]

breed [players player]
players-own [u0 u1 u2 u3 u4 u5 u6 last-action-idx]

to-report day-utility [x]
  report x * exp ((0 - x) / 3)
end

to-report global-utility-from-counts [a0 a1 a2 a3 a4 a5 a6]
  report (day-utility a0) + (day-utility a1) + (day-utility a2) +
         (day-utility a3) + (day-utility a4) + (day-utility a5) + (day-utility a6)
end

to recompute-attendance
  set attendance0 0
  set attendance1 0
  set attendance2 0
  set attendance3 0
  set attendance4 0
  set attendance5 0
  set attendance6 0
  ask players [
    if last-action-idx = 0 [ set attendance0 attendance0 + 1 ]
    if last-action-idx = 1 [ set attendance1 attendance1 + 1 ]
    if last-action-idx = 2 [ set attendance2 attendance2 + 1 ]
    if last-action-idx = 3 [ set attendance3 attendance3 + 1 ]
    if last-action-idx = 4 [ set attendance4 attendance4 + 1 ]
    if last-action-idx = 5 [ set attendance5 attendance5 + 1 ]
    if last-action-idx = 6 [ set attendance6 attendance6 + 1 ]
  ]
end

to recompute-rewards
  set current-utility global-utility-from-counts attendance0 attendance1 attendance2 attendance3 attendance4 attendance5 attendance6
  set reward0 1 + current-utility - global-utility-from-counts (attendance0 - 1 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 + (1 / 7))
  set reward1 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 - 1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 + (1 / 7))
  set reward2 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 - 1 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 + (1 / 7))
  set reward3 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 - 1 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 + (1 / 7))
  set reward4 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 - 1 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 + (1 / 7))
  set reward5 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 - 1 + (1 / 7)) (attendance6 + (1 / 7))
  set reward6 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 - 1 + (1 / 7))
end

to-report stochastic-choice-7 [w0 w1 w2 w3 w4 w5 w6]
  let total (w0 + w1 + w2 + w3 + w4 + w5 + w6)
  let r random-float total
  if r <= w0 [ report 0 ]
  set r r - w0
  if r <= w1 [ report 1 ]
  set r r - w1
  if r <= w2 [ report 2 ]
  set r r - w2
  if r <= w3 [ report 3 ]
  set r r - w3
  if r <= w4 [ report 4 ]
  set r r - w4
  if r <= w5 [ report 5 ]
  report 6
end

to setup
  clear-all
  set num-agents 63
  set discount-rate 0.98
  set current-utility 0
  create-players num-agents [
    hide-turtle
    setxy 0 who
    set u0 100
    set u1 100
    set u2 100
    set u3 100
    set u4 100
    set u5 100
    set u6 100
    set last-action-idx 0
  ]
  repeat 100 [
    ask players [take-random-action]
    recompute-attendance
    recompute-rewards
    ask players [learn]
  ]
  recompute-attendance
  set current-utility global-utility-from-counts attendance0 attendance1 attendance2 attendance3 attendance4 attendance5 attendance6
  reset-ticks
end

to go
  ask players [take-action]
  recompute-attendance
  recompute-rewards
  ask players [learn]
  tick
end

to take-action
  set last-action-idx stochastic-choice-7 u0 u1 u2 u3 u4 u5 u6
end

to take-random-action
  set last-action-idx random 7
end

to learn
  set u0 u0 * discount-rate
  set u1 u1 * discount-rate
  set u2 u2 * discount-rate
  set u3 u3 * discount-rate
  set u4 u4 * discount-rate
  set u5 u5 * discount-rate
  set u6 u6 * discount-rate
  if last-action-idx = 0 [ set u0 u0 + reward0 ]
  if last-action-idx = 1 [ set u1 u1 + reward1 ]
  if last-action-idx = 2 [ set u2 u2 + reward2 ]
  if last-action-idx = 3 [ set u3 u3 + reward3 ]
  if last-action-idx = 4 [ set u4 u4 + reward4 ]
  if last-action-idx = 5 [ set u5 u5 + reward5 ]
  if last-action-idx = 6 [ set u6 u6 + reward6 ]
end
"""
    globals = ["current-utility"]
    nticks = 200
    dims = (-16, 16, -16, 16)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = CoinParams(
                num_agents=63, discount_rate=0.98,
                warmup=100, max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_coin(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            vals = Dict{String, Vector{Float64}}(
                "current-utility" => Float64[v[1] for v in trajectory],
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("COIN Learning", nlogo_src, nticks, globals, ark_runner)
end

# ── 7. Virus on a Network ───────────────────────────────────────────

function define_virus()
    code = """
globals [randomSeed num-susceptible num-infected num-resistant]
turtles-own [infected? resistant? virus-timer]

to setup
  clear-all
  create-turtles 150 [
    setxy random-xcor random-ycor
    set infected? false
    set resistant? false
    set virus-timer 0
    set color green
    set shape "circle"
    set size 0.5
  ]
  ask turtles [
    create-links-with other turtles in-radius 3
  ]
  ask n-of 3 turtles [
    become-infected
  ]
  update-counts
  reset-ticks
end

to go
  if num-infected = 0 [ stop ]
  ask turtles with [infected?] [
    ask link-neighbors with [not resistant? and not infected?] [
      if random-float 1.0 < 0.10 [
        become-infected
      ]
    ]
    set virus-timer virus-timer + 1
    if virus-timer > 10 [
      ifelse random-float 1.0 < 0.25 [
        become-resistant
      ] [
        become-susceptible
      ]
    ]
  ]
  ask turtles with [resistant?] [
    if random-float 1.0 < 0.01 [
      become-susceptible
    ]
  ]
  update-counts
  tick
end

to become-infected
  set infected? true
  set resistant? false
  set virus-timer 0
  set color red
end

to become-resistant
  set infected? false
  set resistant? true
  set virus-timer 0
  set color gray
end

to become-susceptible
  set infected? false
  set resistant? false
  set virus-timer 0
  set color green
end

to update-counts
  set num-susceptible count turtles with [not infected? and not resistant?]
  set num-infected count turtles with [infected?]
  set num-resistant count turtles with [resistant?]
end
"""
    globals = ["num-susceptible", "num-infected", "num-resistant"]
    nticks = 150
    dims = (-25, 25, -25, 25)

    function ark_runner(seeds::Vector{Int})
        trajs = TrajectoryData[]
        for seed in seeds
            params = VirusParams(
                number_people=150, infectiousness=65.0,
                duration=20.0, chance_recover=75.0,
                lifespan=100, carrying_capacity=300,
                average_offspring=4, initial_infected=10,
                grid_size=51, max_ticks=nticks, seed=seed
            )
            scheduler, trajectory = run_virus(params=params)
            tick_nums = collect(0:length(trajectory)-1)
            # Ark observer returns [pct_infected, pct_immune, total_population].
            # Convert to absolute counts matching NetLogo globals.
            n_sus = Float64[]
            n_inf = Float64[]
            n_res = Float64[]
            for v in trajectory
                pct_infected, pct_immune, total_pop = v
                ni = round(total_pop * pct_infected / 100.0)
                nr = round(total_pop * pct_immune / 100.0)
                ns = total_pop - ni - nr
                push!(n_inf, ni)
                push!(n_res, nr)
                push!(n_sus, ns)
            end
            vals = Dict{String, Vector{Float64}}(
                "num-susceptible" => n_sus,
                "num-infected"    => n_inf,
                "num-resistant"   => n_res,
            )
            push!(trajs, TrajectoryData(seed, tick_nums, vals))
        end
        trajs
    end

    nlogo_src = build_nlogo_source(code, nticks, globals; world_dims=dims)
    ("Virus on Network", nlogo_src, nticks, globals, ark_runner)
end
