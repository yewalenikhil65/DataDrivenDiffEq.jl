@testset "Linear Discrete System" begin
    # Create some linear data
    A = [0.9 -0.2; 0.0 0.2]
    y = [[10.; -10.]]
    for i in 1:10
        push!(y, A*y[end])
    end
    X = hcat(y...)
    prob = DiscreteDataDrivenProblem(X, t = 1:11)

    for alg in [DMDPINV(), DMDSVD(), TOTALDMD()]
        # Returns a named
        estimator = solve(prob, alg , operator_only = true)
        @test Matrix(estimator.K) ≈ A
        @test eigvals(estimator.K) ≈ eigvals(A)
        @test estimator.C ≈ diagm(ones(2))
        @test isempty(estimator.B)

        res = solve(prob, alg , operator_only = false)
        m = metrics(res)
        @test all(m[:L₂] ./ size(X, 2) .< 3e-1)
        @test Matrix(result(res)) ≈ Matrix(estimator.K)
    end
end

# test adopted for fbDMD from https://github.com/mathLab/PyDMD/blob/master/tests/test_fbdmd.py
@testset "Linear Discrete System from PyDMD" begin
    # Create some linear data
    A = (1/√3)*[1 1;-1 2];
    y = [[.5; 1.]];
    for i in 1:99
        push!(y, A*y[end])
    end
    X= hcat(y...);
    prob = DiscreteDataDrivenProblem(X, t = 1:100);

    for alg in [DMDPINV(), DMDSVD(), fbDMD() ,TOTALDMD()]
        # Returns a named
        estimator = solve(prob, alg , operator_only = true)
        @test isapprox(Matrix(estimator.K), A, atol = 1e-2)
        @test isapprox(eigvals(estimator.K), eigvals(A), atol = 1e-2)
        @test estimator.C ≈ diagm(ones(2))
        @test isempty(estimator.B)
        res = solve(prob, alg , operator_only = false)
        m = metrics(res)
        @test all(m[:L₂] ./ size(X, 2) .< 3e-1)
        @test Matrix(result(res)) ≈ Matrix(estimator.K)
    end
end

@testset "Linear Continuous System" begin
    A = [-0.9 0.1; 0.0 -0.2]
    f(u, p, t) = A*u
    u0 = [10.0; -20.0]
    prob = ODEProblem(f, u0, (0.0, 10.0))
    sol = solve(prob, Tsit5(), saveat = 0.001)

    prob = DataDrivenProblem(sol)

    for alg in [DMDPINV(), DMDSVD(), TOTALDMD()]
        estimator = solve(prob, alg , operator_only = true)
        @test isapprox(Matrix(estimator.K), A, atol = 1e-2)
        @test isapprox(eigvals(estimator.K), eigvals(A), atol = 1e-2)
        @test estimator.C ≈ diagm(ones(2))
        @test isempty(estimator.B)
        res = solve(prob, alg , operator_only = false)
        m = metrics(res)
        @test all(m[:L₂] ./ length(prob) .< 3e-1)
        @test Matrix(result(res)) ≈ Matrix(estimator.K)
    end
end


@testset "Low Rank Continuous System" begin
    K̃ = -0.5*I + [0 0 -0.2; 0.1 0 -0.1; 0. -0.2 0]
    F = qr(randn(20, 3))
    Q = F.Q[:, 1:3]
    dudt(u, p, t) = K̃*u
    prob = ODEProblem(dudt, [10.0; 0.3; -5.0], (0.0, 10.0))
    sol_ = solve(prob, Tsit5(), saveat = 0.01)

    # True Rank is 3
    X = Q*sol_[:,:] + 1e-3*randn(20, 1001)
    DX = Q*sol_(sol_.t, Val{1})[:,:] + 1e-3*randn(20, 1001)
    ddprob = ContinuousDataDrivenProblem(X, sol_.t, DX = DX)

    for alg in [TOTALDMD(3, DMDPINV()); TOTALDMD(0.01, DMDSVD(3))]
        res = solve(ddprob, alg, digits = 2)
        K = Matrix(result(res))
        m = metrics(res)
        @test Q'*K*Q ≈ K̃ atol = 1e-1
        @test Q*K̃*Q' ≈ K atol = 1e-1
        @test all(m[:L₂] ./ length(ddprob) .< 1e-2)
    end
end

@testset "Big System" begin
    # Creates a big system which would resulting in a segfault otherwise
    X = rand([0, 1], 128, 936);
    T = collect(LinRange(0, 4.367058580858928, 936));
    problem = DiscreteDataDrivenProblem(X, T);
    @test_nowarn res2 = solve(problem, DMDSVD(), operator_only = true)
end
