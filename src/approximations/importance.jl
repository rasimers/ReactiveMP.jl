export ImportanceSamplingApproximation

using Random

"""
    ImportanceSamplingApproximation

This structure stores all information needed to perform an importance sampling procedure and provides
convenient functions to generate samples and weights to approximate expectations

# Fields
- `rng`: random number generator objects
- `nsamples`: number of samples generated by default
"""
struct ImportanceSamplingApproximation{T, R}
    rng      :: R
    nsamples :: Int
    bsamples :: Vector{T}
    bweights :: Vector{T}
end

ImportanceSamplingApproximation(rng::R, nsamples::Int)            where { R }    = ImportanceSamplingApproximation(Float64, rng, nsamples) 
ImportanceSamplingApproximation(::Type{T}, rng::R, nsamples::Int) where { T, R } = ImportanceSamplingApproximation{T, R}(rng, nsamples, Vector{T}(undef, nsamples), Vector{T}(undef, nsamples))

getsamples(approximation::ImportanceSamplingApproximation, distribution)           = getsamples(approximation, distribution, approximation.nsamples)
getsamples(approximation::ImportanceSamplingApproximation, distribution, nsamples) = rand(approximation.rng, distribution, nsamples)

function approximate_meancov(approximation::ImportanceSamplingApproximation, g::Function, distribution)

    # We use preallocated arrays to sample and compute transformed samples and weightd
    rand!(approximation.rng, distribution, approximation.bsamples)
    map!(g, approximation.bweights, approximation.bsamples)

    normalization = sum(approximation.bweights)

    map!(Base.Fix2(/, normalization), approximation.bweights, approximation.bweights)
    
    m = mapreduce(prod, +, zip(approximation.bweights, approximation.bsamples))

    _v = let m = m
        (r) -> r[1] * (r[2] - m) ^ 2
    end

    v = mapreduce(_v, +, zip(approximation.bweights, approximation.bsamples))

    return m, v

end