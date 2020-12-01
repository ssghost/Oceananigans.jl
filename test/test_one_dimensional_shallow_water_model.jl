# # One dimensional shallow water example

using Oceananigans
using Oceananigans.Models: ShallowWaterModel
using Oceananigans.Grids: Periodic, Bounded

grid = RegularCartesianGrid(size=(64, 1, 1), extent=(2π, 2π, 2π))

model = ShallowWaterModel(        grid = grid,
                          architecture = CPU(),
                             advection = nothing, 
                              coriolis = nothing
                                  )

width = 0.3
 h(x, y, z)  = 1.0 + 0.1 * exp(-(x - π)^2 / (2width^2));  
uh(x, y, z) = 0.0
vh(x, y, z) = 0.0 

set!(model, uh = uh, vh = vh, h = h)

simulation = Simulation(model, Δt = 0.1, stop_iteration = 10)

run!(simulation)
