using Oceananigans: short_show

"""
    struct DiscreteForcing{P, F}

Wrapper for "discrete form" forcing functions with optional
`parameters`.
"""
struct DiscreteForcing{P, F}
    func :: F
    parameters :: P
end

"""
    DiscreteForcing(func; parameters=nothing)

Construct a "discrete form" forcing function with optional parameters.
The forcing function is applied at grid point `i, j, k`.

When `parameters` are not specified, `func` must be callable with the signature

    `func(i, j, k, grid, clock, model_fields)`

where `grid` is `model.grid`, `clock.time` is the current simulation time and
`clock.iteration` is the current model iteration, and
`model_fields` is a `NamedTuple` with `u, v, w`, the fields in `model.tracers`,
and the fields in `model.diffusivities`, each of which is an `OffsetArray`s (or `NamedTuple`s
of `OffsetArray`s depending on the turbulence closure) of field data.

*Note* that the index `end` does *not* access the final physical grid point of
a model field in any direction. The final grid point must be explicitly specified, as
in `model_fields.u[i, j, grid.Nz]`.

When `parameters` _is_ specified, `func` must be callable with the signature.

    `func(i, j, k, grid, clock, model_fields, parameters)`
    
`parameters` is arbitrary in principle, however GPU compilation can place
constraints on `typeof(parameters)`.
"""
DiscreteForcing(func; parameters=nothing) = DiscreteForcing(func, parameters)

@inline function (forcing::DiscreteForcing{P, F})(i, j, k, grid, clock, model_fields) where {P, F<:Function}
    parameters = forcing.parameters
    return forcing.func(i, j, k, grid, clock, model_fields, parameters)
end

@inline (forcing::DiscreteForcing{<:Nothing, F})(i, j, k, grid, clock, model_fields) where F<:Function =
    forcing.func(i, j, k, grid, clock, model_fields)

"""Show the innards of a `DiscreteForcing` in the REPL."""
Base.show(io::IO, forcing::DiscreteForcing{P}) where P =
    print(io, "DiscreteForcing{$P}", '\n',
        "├── func: $(short_show(forcing.func))", '\n',
        "└── parameters: $(forcing.parameters)")
