export CVIApproximation, CVI

using Random

"""
    cvi_update!(opt, λ, ∇)
"""
function cvi_update! end

function cvi_update!(callback::F, λ, ∇) where {F <: Function}
    return callback(λ, ∇)
end

cvilinearize(vector::AbstractVector) = vector
cvilinearize(matrix::AbstractMatrix) = eachcol(matrix)

"""
    CVIApproximation

The `CVIApproximation` structure defines the approximation method of the `Delta` factor node.
This method performs an approximation of the messages through the `Delta` factor node with Stochastic Variational message passing (SVMP-CVI) (See [`Probabilistic programming with stochastic variational message passing`](https://biaslab.github.io/publication/probabilistic_programming_with_stochastic_variational_message_passing/)).

Arguments
 - `rng`: random number generator
 - `n_samples`: number of samples to use for statistics approximation
 - `num_iterations`: number of iteration for the natural parameters gradient optimization
 - `opt`: optimizer, which will be used to perform the natural parameters gradient optimization step
 - `warn`: optional, defaults to false, enables or disables warnings related to the optimization steps

!!! note 
    Run `using Flux` in your Julia session to enable the `Flux` optimizers support for the CVI approximation method.

"""
struct CVIApproximation{R, O} <: AbstractApproximationMethod
    rng::R
    n_samples::Int
    num_iterations::Int
    opt::O
    warn::Bool
end

function CVIApproximation(rng::AbstractRNG, n_samples::Int, num_iterations::Int, opt::O) where {O}
    return CVIApproximation(rng, n_samples, num_iterations, opt, false)
end

function CVIApproximation(n_samples::Int, num_iterations::Int, opt::O, warn::Bool = false) where {O}
    return CVIApproximation(Random.GLOBAL_RNG, n_samples, num_iterations, opt, warn)
end

"""
Alias for the `CVIApproximation` method.

See also: [`CVIApproximation`](@ref)
"""
const CVI = CVIApproximation

#---------------------------
# CVI implementations
#---------------------------

function render_cvi(approximation::CVIApproximation, logp_nc::F, initial) where {F}
    η = naturalparams(initial)
    λ = naturalparams(initial)
    T = typeof(η)

    rng = something(approximation.rng, Random.GLOBAL_RNG)
    opt = approximation.opt
    its = approximation.num_iterations

    hasupdated = false

    A = (vec_params) -> lognormalizer(as_naturalparams(T, vec_params))
    gradA = (vec_params) -> ForwardDiff.gradient(A, vec_params)
    Fisher = (vec_params) -> ForwardDiff.jacobian(gradA, vec_params)

    for _ in 1:its
        q = convert(Distribution, λ)
        _, q_friendly = logpdf_sample_friendly(q)

        z_s = rand(rng, q_friendly)

        logq = (vec_params) -> logpdf(as_naturalparams(T, vec_params), z_s)
        ∇logq = ForwardDiff.gradient(logq, vec(λ))

        ∇f = Fisher(vec(λ)) \ (logp_nc(z_s) .* ∇logq)
        ∇ = λ - η - as_naturalparams(T, ∇f)
        updated = as_naturalparams(T, cvi_update!(opt, λ, ∇))

        if isproper(updated)
            λ = updated
            hasupdated = true
        end
    end

    if !hasupdated && approximation.warn
        @warn "CVI approximation has not updated the initial state. The method did not converge. Set `warn = false` to supress this warning."
    end

    return λ
end