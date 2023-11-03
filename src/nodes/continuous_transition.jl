export transfominator, CTransition, ContinuousTransition, CTMeta

import LazyArrays
import StatsFuns: log2π

@doc raw"""
The ContinuousTransition node transforms an m-dimensional (dx) vector x into an n-dimensional (dy) vector y via a linear transformation with a n×m-dimensional matrix H that is constructed from a n*m-dimensional vector h.

To construct the matrix H, the elements of h are filled into H starting with the first row, one element at a time.

The transformation is performed with the following syntax:

```julia
y ~ ContinuousTransition(x, h, Λ)
```
Interfaces:
1. y - n-dimensional output of the ContinuousTransition node.
2. x - m-dimensional input of the ContinuousTransition node.
3. h - nm-dimensional vector that casts into the matrix H.
4. Λ - n×n-dimensional precision matrix used to soften the transition and perform variational message passing, as belief-propagation is not feasible for y = Hx.

Note that you can set Λ to a fixed value or put a prior on it to control the amount of jitter.
"""
struct ContinuousTransition end

const transfominator = ContinuousTransition
const CTransition = ContinuousTransition

@node ContinuousTransition Stochastic [y, x, h, Λ]

struct CTMeta
    ds::Tuple # dimensionality of ContinuousTransition (dy, dx)
    Fs::Vector{<:AbstractMatrix} # masks
    es::Vector{<:AbstractVector} # unit vectors

    function CTMeta(ds::Tuple{T, T}) where {T <: Integer}
        dy, dx = ds
        Fs = [ctmask(dx, dy, i) for i in 1:dy]
        es = [StandardBasisVector(dy, i, one(T)) for i in 1:dy]
        return new(ds, Fs, es)
    end

    function CTMeta(dy::T, dx::T) where {T <: Integer}
        Fs = [ctmask(dx, dy, i) for i in 1:dy]
        es = [StandardBasisVector(dy, i, one(T)) for i in 1:dy]
        return new((dy, dx), Fs, es)
    end
end

@average_energy ContinuousTransition (q_y_x::MultivariateNormalDistributionsFamily, q_h::MultivariateNormalDistributionsFamily, q_Λ::Wishart, meta::CTMeta) = begin
    mh, Vh   = mean_cov(q_h)
    myx, Vyx = mean_cov(q_y_x)
    mΛ       = mean(q_Λ)

    dy, dx = getdimensionality(meta)
    Fs, es = getmasks(meta), getunits(meta)
    n      = div(ndims(q_y_x), 2)
    mH     = ctcompanion_matrix(mh, meta)
    mx, Vx = myx[(dy + 1):end], Vyx[(dy + 1):end, (dy + 1):end]
    my, Vy = myx[1:dy], Vyx[1:dy, 1:dy]
    Vyx    = Vyx[1:dy, (dy + 1):end]
    g₁     = my' * mΛ * my + tr(Vy * mΛ)
    g₂     = mx' * mH' * mΛ * my + tr(Vyx * mH' * mΛ)
    g₃     = g₂
    G      = sum(sum(es[i]' * mΛ * es[j] * Fs[i] * (mh * mh' + Vh) * Fs[j]' for i in 1:length(Fs)) for j in 1:length(Fs))
    g₄     = mx' * G * mx + tr(Vx * G)
    AE     = n / 2 * log2π - 0.5 * mean(logdet, q_Λ) + 0.5 * (g₁ - g₂ - g₃ + g₄)

    return AE
end

getdimensionality(meta::CTMeta) = meta.ds
getmasks(meta::CTMeta)          = meta.Fs
getunits(meta::CTMeta)          = meta.es

@node ContinuousTransition Stochastic [y, x, h, Λ]

default_meta(::Type{CTMeta}) = error("ContinuousTransition node requires meta flag explicitly specified")

function ctmask(dim1, dim2, index)
    F = zeros(dim1, dim1 * dim2)
    start_col = (index - 1) * dim1 + 1
    end_col = start_col + dim1 - 1
    @inbounds F[1:dim1, start_col:end_col] = I(dim1)
    return F
end

function ctcompanion_matrix(w, meta::CTMeta)
    Fs, es = getmasks(meta), getunits(meta)
    dy, _ = getdimensionality(meta)
    L = sum(es[i] * w' * Fs[i]' for i in 1:dy)
    return L
end
