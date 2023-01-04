@rule MAR(:Λ, Marginalisation) (
    q_y_x::MultivariateNormalDistributionsFamily,
    q_a::MultivariateNormalDistributionsFamily,
    meta::MARMeta
) = begin
    order, ds = getorder(meta), getdimensionality(meta)
    F = Multivariate
    dim = order*ds

    n = div(ndims(q_y_x), 2)

    y_x_mean, y_x_cov = mean_cov(q_y_x)
    ma, Va = mean_cov(q_a)

    mA = mar_companion_matrix(order, ds, ma)

    myx, Vyx = mean_cov(q_y_x)
    my, Vy   = ar_slice(F, myx, 1:dim), ar_slice(F, Vyx, 1:dim, 1:dim)
    mx, Vx   = ar_slice(F, myx, (dim+1):2dim), ar_slice(F, Vyx, (dim+1):2dim, (dim+1):2dim)
    Vyx      = ar_slice(F, Vyx, (dim+1):2dim, 1:dim)

    es = [uvector(dim, i) for i in 1:ds]
    Fs = [mask_mar(order, ds, i) for i in 1:ds]
    S = mar_shift(order, ds)
    G₁ = (my*my' + Vy)[1:ds, 1:ds]
    G₂ = ((my*mx' + Vyx)*mA')[1:ds, 1:ds]
    G₃ = transpose(G₂)
    Ex_xx = mx*mx' + Vx
    G₅ = sum(sum(es[i]*ma'*Fs[j]'Ex_xx*Fs[i]*ma*es[j]' for i in 1:ds) for j in 1:ds)[1:ds, 1:ds]
    G₆ = sum(sum(es[i]*tr(Va*Fs[i]'*Ex_xx*Fs[j])*es[j]' for i in 1:ds) for j in 1:ds)[1:ds, 1:ds]
    Δ = G₁ + G₂ + G₃ + G₅ + G₆

    return WishartMessage(n+2, Δ)
end

@rule MAR(:Λ, Marginalisation) (
    q_y::MultivariateNormalDistributionsFamily,
    q_x::MultivariateNormalDistributionsFamily,
    q_a::MultivariateNormalDistributionsFamily,
    meta::MARMeta
) = begin
    order, ds = getorder(meta), getdimensionality(meta)
    F = Multivariate
    dim = order*ds

    my, Vy = mean_cov(q_y)
    mx, Vx = mean_cov(q_x)
    ma, Va = mean_cov(q_a)

    mA = mar_companion_matrix(order, ds, ma)

    es = [uvector(dim, i) for i in 1:ds]
    Fs = [mask_mar(order, ds, i) for i in 1:ds]
    S = mar_shift(order, ds)
    G₁ = (my*my' + Vy)[1:ds, 1:ds]
    G₂ = (my*mx'*mA')[1:ds, 1:ds]
    G₃ = transpose(G₂)
    Ex_xx = mx*mx' + Vx
    G₅ = sum(sum(es[i]*ma'*Fs[j]'Ex_xx*Fs[i]*ma*es[j]' for i in 1:ds) for j in 1:ds)[1:ds, 1:ds]
    G₆ = sum(sum(es[i]*tr(Va*Fs[i]'*Ex_xx*Fs[j])*es[j]' for i in 1:ds) for j in 1:ds)[1:ds, 1:ds]
    Δ = G₁ + G₂ + G₃ + G₅ + G₆

    return WishartMessage(length(my)+2, Δ)
end