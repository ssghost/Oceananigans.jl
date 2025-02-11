using Oceananigans: AbstractModel, AbstractOutputWriter, AbstractDiagnostic

using Oceananigans.Architectures: AbstractArchitecture
using Oceananigans.Advection: CenteredSecondOrder
using Oceananigans.BoundaryConditions: regularize_field_boundary_conditions

using Oceananigans.BoundaryConditions: UVelocityBoundaryConditions,
                                       VVelocityBoundaryConditions,
                                       TracerBoundaryConditions

using Oceananigans.Fields: Field, tracernames, TracerFields, XFaceField, YFaceField, CellField
using Oceananigans.Forcings: model_forcing
using Oceananigans.Grids: with_halo
using Oceananigans.TimeSteppers: Clock, TimeStepper, RungeKutta3TimeStepper
using Oceananigans.TurbulenceClosures: ν₀, κ₀, with_tracers, DiffusivityFields, IsotropicDiffusivity
using Oceananigans.Utils: inflate_halo_size, tupleit

function ShallowWaterTendencyFields(arch, grid, tracer_names)

    uh = XFaceField(arch, grid, UVelocityBoundaryConditions(grid))
    vh = YFaceField(arch, grid, VVelocityBoundaryConditions(grid))
    h  = CellField(arch,  grid, TracerBoundaryConditions(grid))
    tracers = TracerFields(tracer_names, arch, grid)
    
    return merge((uh=uh, vh=vh, h=h), tracers)
end

function ShallowWaterSolutionFields(arch, grid, bcs)
    
    uh_bcs = :uh ∈ keys(bcs) ? bcs.uh : UVelocityBoundaryConditions(grid)
    vh_bcs = :vh ∈ keys(bcs) ? bcs.vh : VVelocityBoundaryConditions(grid)
    h_bcs  = :h  ∈ keys(bcs) ? bcs.h  : TracerBoundaryConditions(grid)

    uh = XFaceField(arch, grid, uh_bcs)
    vh = YFaceField(arch, grid, vh_bcs)
    h = CellField(arch, grid, h_bcs)

    return (uh=uh, vh=vh, h=h)
end

struct ShallowWaterModel{G, A<:AbstractArchitecture, T, V, R, F, E, Q, C, K, TS} <: AbstractModel{TS}
    
                 grid :: G         # Grid of physical points on which `Model` is solved
         architecture :: A         # Computer `Architecture` on which `Model` is run
                clock :: Clock{T}  # Tracks iteration number and simulation time of `Model`
            advection :: V         # Advection scheme for velocities _and_ tracers
             coriolis :: R         # Set of parameters for the background rotation rate of `Model`
              forcing :: F         # Container for forcing functions defined by the user
              closure :: E         # Diffusive 'turbulence closure' for all model fields
             solution :: Q         # Container for transports `uh`, `vh`, and height `h`
              tracers :: C         # Container for tracer fields
        diffusivities :: K         # Container for turbulent diffusivities
          timestepper :: TS        # Object containing timestepper fields and parameters

end

function ShallowWaterModel(;
                           grid,
  architecture::AbstractArchitecture = CPU(),
                          float_type = Float64,
                               clock = Clock{float_type}(0, 0, 1),
                           advection = UpwindBiasedFifthOrder(),
                            coriolis = nothing,
                             forcing = NamedTuple(),
                             closure = nothing,
                            solution = nothing,
                 tracers::NamedTuple = NamedTuple(),
                       diffusivities = nothing,
     boundary_conditions::NamedTuple = NamedTuple())

    grid.Nz == 1 || throw(ArgumentError("ShallowWaterModel must be constructed with Nz=1!"))

    tracers = tupleit(tracers) # supports tracers=:c keyword argument (for example)

    Hx, Hy, Hz = inflate_halo_size(grid.Hx, grid.Hy, grid.Hz, advection)
    grid = with_halo((Hx, Hy, Hz), grid)
    
    boundary_conditions = regularize_field_boundary_conditions(boundary_conditions, grid, nothing)
    
    solution = ShallowWaterSolutionFields(architecture, grid, boundary_conditions)
    tracers  = TracerFields(tracers, architecture, grid, boundary_conditions)
    diffusivities = DiffusivityFields(diffusivities, architecture, grid,
                                      tracernames(tracers), boundary_conditions, closure)

    timestepper = RungeKutta3TimeStepper(architecture, grid, tracernames(tracers);
                                         Gⁿ = ShallowWaterTendencyFields(architecture, grid, tracernames(tracers)),
                                         G⁻ = ShallowWaterTendencyFields(architecture, grid, tracernames(tracers)))

    # Regularize forcing and closure for model tracer and velocity fields.
    forcing = model_forcing(tracernames(tracers); forcing...)
    closure = with_tracers(tracernames(tracers), closure)
    
    return ShallowWaterModel(grid,
                             architecture,
                             clock,
                             advection,
                             coriolis,
                             forcing,
                             closure,
                             solution,
                             tracers,
                             diffusivities,
                             timestepper)
end
