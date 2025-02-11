# Tracers

The tracers to be advected around can be specified via a list of symbols. By default the model evolves temperature and
salinity

```@meta
DocTestSetup = quote
    using Oceananigans
end
```

```jldoctest tracers
julia> grid = RegularCartesianGrid(size=(64, 64, 64), extent=(1, 1, 1));

julia> model = IncompressibleModel(grid=grid)
IncompressibleModel{CPU, Float64}(time = 0 seconds, iteration = 0)
├── grid: RegularCartesianGrid{Float64, Periodic, Periodic, Bounded}(Nx=64, Ny=64, Nz=64)
├── tracers: (:T, :S)
├── closure: IsotropicDiffusivity{Float64,NamedTuple{(:T, :S),Tuple{Float64,Float64}}}
├── buoyancy: SeawaterBuoyancy{Float64,LinearEquationOfState{Float64},Nothing,Nothing}
└── coriolis: Nothing
```

whose fields can be accessed via `model.tracers.T` and `model.tracers.S`.

```jldoctest tracers
julia> model.tracers.T
Field located at (Cell, Cell, Cell)
├── data: OffsetArrays.OffsetArray{Float64,3,Array{Float64,3}}, size: (66, 66, 66)
├── grid: RegularCartesianGrid{Float64, Periodic, Periodic, Bounded}(Nx=64, Ny=64, Nz=64)
└── boundary conditions: x=(west=Periodic, east=Periodic), y=(south=Periodic, north=Periodic), z=(bottom=ZeroFlux, top=ZeroFlux)

julia> model.tracers.S
Field located at (Cell, Cell, Cell)
├── data: OffsetArrays.OffsetArray{Float64,3,Array{Float64,3}}, size: (66, 66, 66)
├── grid: RegularCartesianGrid{Float64, Periodic, Periodic, Bounded}(Nx=64, Ny=64, Nz=64)
└── boundary conditions: x=(west=Periodic, east=Periodic), y=(south=Periodic, north=Periodic), z=(bottom=ZeroFlux, top=ZeroFlux)

```

Any number of arbitrary tracers can be appended to this list and passed to a model constructor. For example, to evolve
quantities ``C_1``, CO₂, and nitrogen as additional passive tracers you could set them up as

```jldoctest tracers
julia> model = IncompressibleModel(grid=grid, tracers=(:T, :S, :C₁, :CO₂, :nitrogen))
IncompressibleModel{CPU, Float64}(time = 0 seconds, iteration = 0)
├── grid: RegularCartesianGrid{Float64, Periodic, Periodic, Bounded}(Nx=64, Ny=64, Nz=64)
├── tracers: (:T, :S, :C₁, :CO₂, :nitrogen)
├── closure: IsotropicDiffusivity{Float64,NamedTuple{(:T, :S, :C₁, :CO₂, :nitrogen),NTuple{5,Float64}}}
├── buoyancy: SeawaterBuoyancy{Float64,LinearEquationOfState{Float64},Nothing,Nothing}
└── coriolis: Nothing
```

!!! info "Active vs. passive tracers"
    An active tracer typically denotes a tracer quantity that affects the fluid dynamics through buoyancy. In the ocean
    temperature and salinity are active tracers. Passive tracers, on the other hand, typically do not affect the fluid
    dynamics are are _passively_ advected around by the flow field.
