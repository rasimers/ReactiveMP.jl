using Distributions

# TODO: check
function multiply_messages(m1::Message{N}, m2::Message{N}) where { N <: NormalMeanPrecision }
    mean1 = mean(m1)
    mean2 = mean(m2)

    var1 = var(m1)
    var2 = var(m2)

    result = N((mean1 * var2 + mean2 * var1) / (var1 + var2), (var1 + var2) / (var1 * var2))

    return Message(result)
end

@symmetrical function multiply_messages(m1::Message{T}, m2::Message{N}) where { T <: Real, N <: NormalMeanPrecision }
    # return Message(Distributions.pdf(getdata(m2), getdata(m1)))
    # return Message(NormalMeanPrecision(mean(m1), var(m2)))
    mean1 = mean(m1)
    mean2 = mean(m2)

    var1 = var(m1)
    var2 = var(m2)

    result = N((mean1 * var2 + mean2 * var1) / (var1 + var2), (var1 + var2) / (var1 * var2))

    return Message(result)
end
