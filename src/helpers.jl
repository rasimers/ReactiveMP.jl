export skipindex, @symmetrical

import Base: IteratorSize, HasLength
import Base: IteratorEltype, HasEltype
import Base: eltype, length, size
import Base: IndexStyle, IndexLinear, getindex

struct SkipIndexIterator{Iterator, T, N} <: AbstractArray{T, N}
    iterator :: Iterator
    skip     :: Int
end

skip(iter::SkipIndexIterator) = iter.skip

function skipindex(iter::Iterator, skip::Int) where Iterator
    @assert skip >= 1
    @assert length(iter) >= 1
    @assert IndexStyle(Iterator) === IndexLinear()
    return SkipIndexIterator{Iterator, eltype(Iterator), 1}(iter, skip)
end

Base.IteratorSize(::Type{<:SkipIndexIterator})   = HasLength()
Base.IteratorEltype(::Type{<:SkipIndexIterator}) = HasEltype()
Base.IndexStyle(::Type{<:SkipIndexIterator})     = IndexLinear()

Base.eltype(::Type{<:SkipIndexIterator{Any, T}}) where T = T
Base.length(iter::SkipIndexIterator) = max(0, length(iter.iterator) - 1)
Base.size(iter::SkipIndexIterator)   = (length(iter), )

Base.getindex(iter::SkipIndexIterator, i) = @inbounds begin i < skip(iter) ? iter.iterator[i] : iter.iterator[i + 1] end

"""
    @symmetrical `function_definition`
Duplicate a method definition with the order of the first two arguments swapped.
This macro is used to duplicate methods that are symmetrical in their first two input arguments,
but require explicit definitions for the different argument orders.
Example:
    @symmetrical function prod!(x, y, z)
        ...
    end
"""
macro symmetrical(fn::Expr)
    # Check if macro is applied to a function definition
    # Valid function definitions include:
    # 1. foo([ args... ]) [ where ... [ where ... [ ... ] ] ] = :block
    # 2. function foo([ args... ]) [ where ... [ where ... [ ... ] ] ]
    #        :block
    #    end
    if (fn.head === :(=) || fn.head === :function) &&
        (fn.args[1] isa Expr && fn.args[2] isa Expr) &&
        (fn.args[2].head === :block)
        return esc(quote
            $fn
            $(swap_arguments(fn))
        end)
    else
        error("@symmetrical macro can be applied only to function definitions")
    end
end

function swap_arguments(fn::Expr)
    swapped = copy(fn)

    if swapped.args[1].head === :where
        swapped.args[1] = swap_arguments(swapped.args[1])
    elseif swapped.args[1].head === :call && length(fn.args[1].args) >= 3 # Note: >= 3, because the first argument is a function name
        swapped.args[1].args[2] = fn.args[1].args[3]
        swapped.args[1].args[3] = fn.args[1].args[2]
    else
        error("Function method passed for @symmetrical macro must have more than 2 arguments")
    end

    return swapped
end
