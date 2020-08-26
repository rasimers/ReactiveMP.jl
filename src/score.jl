export score, AverageEnergy, DifferentialEntropy, BetheFreeEnergy

function score end

struct AverageEnergy end
struct DifferentialEntropy end

struct BetheFreeEnergy end

# TODO: Messages around nodes, not marginals
# TODO: Check if we use clusters instead of marginals
# TODO __score_getmarginal wont work for clusters?
function score(::BetheFreeEnergy, model::Model, scheduler)
    average_energies = map(getnodes(model)) do node
        marginals = combineLatest(map(v -> __score_getmarginal(connectedvar(v)), variables(node)), PushEach())
        return marginals |> schedule_on(scheduler) |> map(Float64, (m) -> score(AverageEnergy(), functionalform(node), m)) 
    end

    differential_entropies = map(getrandom(model)) do random 
        return __score_getmarginal(random) |> schedule_on(scheduler) |> map(Float64, (m) -> score(DifferentialEntropy(), m))
    end

    energies_sum  = combineLatest(average_energies, PushNew()) |> map(Float64, energies -> reduce(+, energies))
    entropies_sum = combineLatest(differential_entropies, PushNew()) |> map(Float64, entropies -> reduce(+, entropies))

    return combineLatest((energies_sum, entropies_sum), PushNew()) |> map(Float64, d -> d[1] - d[2])
end



