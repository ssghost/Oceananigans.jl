# # Two dimensional turbulence example
#
# In this example, we initialize a random velocity field and observe its turbulent decay 
# in a two-dimensional domain. This example demonstrates:
#
#   * How to run a model with no tracers and no buoyancy model.
#   * How to use `AbstractOperations`.
#   * How to use `ComputedField`s to generate output.

# ## Install dependencies
#
# First let's make sure we have all required packages installed.

using Pkg
pkg"add Oceananigans, JLD2, Plots"

# ## Model setup

# We instantiate the model with an isotropic diffusivity. We use a grid with 128² points,
# a fifth-order advection scheme, third-order Runge-Kutta time-stepping,
# and a small isotropic viscosity.

using Oceananigans, Oceananigans.Advection

grid = RegularCartesianGrid(size=(128, 128, 1), extent=(2π, 2π, 2π))

model = IncompressibleModel(timestepper = :RungeKutta3, 
                              advection = UpwindBiasedFifthOrder(),
                                   grid = grid,
                               buoyancy = nothing,
                                tracers = nothing,
                                closure = IsotropicDiffusivity(ν=1e-5)
                           )

# ## Random initial conditions
#
# Our initial condition randomizes `model.velocities.u` and `model.velocities.v`.
# We ensure that both have zero mean for aesthetic reasons.

using Statistics

u₀ = rand(size(model.grid)...)
u₀ .-= mean(u₀)

set!(model, u=u₀, v=u₀)

# ## Computing vorticity and speed

using Oceananigans.Fields, Oceananigans.AbstractOperations

# To make our equations prettier, we unpack `u`, `v`, and `w` from 
# the `NamedTuple` model.velocities:
u, v, w = model.velocities

# Next we create two objects called `ComputedField`s that calculate
# _(i)_ vorticity that measures the rate at which the fluid rotates 
# and is defined as
#
# ```math
# ω = ∂_x v - ∂_y u \, ,
# ```

ω = ∂x(v) - ∂y(u)

ω_field = ComputedField(ω)

# We also calculate _(ii)_ the _speed_ of the flow,
#
# ```math
# s = \sqrt{u^2 + v^2} \, .
# ```

s = sqrt(u^2 + v^2)

s_field = ComputedField(s)

# We'll pass these `ComputedField`s to an output writer below to calculate them during the simulation.
# Now we construct a simulation that prints out the iteration and model time as it runs.

progress(sim) = @info "Iteration: $(sim.model.clock.iteration), time: $(round(Int, sim.model.clock.time))"

simulation = Simulation(model, Δt=0.2, stop_time=50, iteration_interval=100, progress=progress)

# ## Output
#
# We set up an output writer for the simulation that saves the vorticity every 20 iterations.

using Oceananigans.OutputWriters

simulation.output_writers[:fields] = JLD2OutputWriter(model, (ω=ω_field, s=s_field),
                                                      schedule = TimeInterval(2),
                                                      prefix = "two_dimensional_turbulence",
                                                      force = true)

# ## Running the simulation
#
# Pretty much just

run!(simulation)

# ## Visualizing the results
#
# We load the output and make a movie.

using JLD2

file = jldopen(simulation.output_writers[:fields].filepath)

iterations = parse.(Int, keys(file["timeseries/t"]))

# Construct the ``x, y`` grid for plotting purposes,

using Oceananigans.Grids

xω, yω, zω = nodes(ω_field)
xs, ys, zs = nodes(s_field)
nothing #hide

# and animate the vorticity and fluid speed.

using Plots

@info "Making a neat movie of vorticity and speed..."

anim = @animate for (i, iteration) in enumerate(iterations)

    @info "Plotting frame $i from iteration $iteration..."
    
    t = file["timeseries/t/$iteration"]
    ω_snapshot = file["timeseries/ω/$iteration"][:, :, 1]
    s_snapshot = file["timeseries/s/$iteration"][:, :, 1]

    ω_lim = 2.0
    ω_levels = range(-ω_lim, stop=ω_lim, length=20)

    s_lim = 0.2
    s_levels = range(0, stop=s_lim, length=20)

    kwargs = (xlabel="x", ylabel="y", aspectratio=1, linewidth=0, colorbar=true,
              xlims=(0, model.grid.Lx), ylims=(0, model.grid.Ly))
              
    ω_plot = contourf(xω, yω, clamp.(ω_snapshot', -ω_lim, ω_lim);
                       color = :balance,
                      levels = ω_levels,
                       clims = (-ω_lim, ω_lim),
                      kwargs...)

    s_plot = contourf(xs, ys, clamp.(s_snapshot', 0, s_lim);
                       color = :thermal,
                      levels = s_levels,
                       clims = (0, s_lim),
                      kwargs...)

    plot(ω_plot, s_plot, title=["Vorticity" "Speed"], layout=(1, 2), size=(1200, 500))
end

gif(anim, "two_dimensional_turbulence.gif", fps = 8) #hide
