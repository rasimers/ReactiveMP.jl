module ReactiveMPVariableTest

using Test, ReactiveMP, Rocket, BayesBase, Distributions, ExponentialFamily

struct CustomDeterministicNode end

@node CustomDeterministicNode Deterministic [out, (x, aliases = [xx])]

function test_variable_set_method(variable, dist::T) where {T}
    flag = false

    activate!(variable, TestOptions())

    test_out_var = randomvar(:out)

    # messages could be initialized only when the node is created
    test_node = make_node(CustomDeterministicNode, ReactiveMP.FactorNodeCreationOptions(), test_out_var, variable)

    setmessage!(variable, 1, dist)
    setmarginal!(variable, dist)

    subscription = subscribe!(getmarginal(variable, IncludeAll()), (marginal) -> begin
        @test typeof(marginal) <: Marginal{T}
        @test mean(marginal) === mean(dist)
        @test var(marginal) === var(dist)
        flag = true
    end)

    subscription = subscribe!(ReactiveMP.messageout(variable, 1), (message) -> begin
        @test typeof(message) <: Message{T}
        @test mean(message) === mean(dist)
        @test var(message) === var(dist)
    end)

    # Test that subscription happenend
    @test flag === true

    unsubscribe!(subscription)
end

struct TestNodeMetaData end

function test_variables_set_methods(variables, dist::T) where {T}
    flag = false

    activate!.(variables, TestOptions())

    @test_throws AssertionError setmarginals!(variables, Iterators.repeated(dist, length(variables) - 1))

    setmarginals!(variables, dist)

    subscription = subscribe!(getmarginals(variables, IncludeAll()), (marginals) -> begin
        @test length(marginals) === length(variables)
        foreach(marginals) do marginal
            @test typeof(marginal) <: Marginal{T}
            @test mean(marginal) === mean(dist)
            @test var(marginal) === var(dist)
        end
        flag = true
    end)

    # Test that subscription happenend
    @test flag === true

    unsubscribe!(subscription)
end

@testset "Variable" begin
    import ReactiveMP: activate!
    import Rocket: getscheduler

    struct TestOptions end

    Rocket.getscheduler(::TestOptions) = AsapScheduler()
    Base.broadcastable(::TestOptions) = Ref(TestOptions()) # for broadcasting

    @testset "setmarginal! tests for randomvar" begin
        for dist in (NormalMeanVariance(-2.0, 3.0), NormalMeanPrecision(-2.0, 3.0), PointMass(2.0))
            test_variable_set_method(randomvar(:r), dist)
            test_variables_set_methods(randomvar(:r, 2), dist)
            test_variables_set_methods(randomvar(:r, 2, 2), dist)
        end
    end
end

end
