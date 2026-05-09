using DataFrames
using CSV
using Statistics
using Plots

function plot_filter(df :: DataFrame, f :: Function, time_or_res :: Bool = true)

    filtered = filter(f, df)

    col = time_or_res ? (:Runtime) : (:Robots)
    y = time_or_res ? "Time (ms)" : "Diff to Best"

    #=
    stats = combine(
        groupby(filtered, [:Algorithm, :Size]),
        col => mean => :Middle,
        col => (x -> quantile(x, 0.75) - mean(x)) => :Upper,
        col => (x -> mean(x) - quantile(x, 0.5)) => :Lower
    )
    =#

    stats = combine(
        groupby(filtered, [:Algorithm, :Size]),
        col => mean => :Middle,
        col => std => :Std
    )

    p = plot(
        xlabel = "Problem size",
        ylabel = y,
        legend = :outertopright
    )

    for alg in unique(stats.Algorithm)

        subdf = filter(x -> x.Algorithm == alg, stats)

        plot!(
            p,
            subdf.Size,
            subdf.Middle,
            ribbon = subdf.Std,
            fillalpha = 0.1,
            label = alg
        )

    end

    return p 
end

time_greedy_simplex(x) = x.Algorithm in ["Greedy", "Greedy + 2opt"] && x.Generator == "Simplex"
time_greedy_planted(x) = x.Algorithm in ["Greedy", "Greedy + 2opt"] && x.Generator == "Planted"
time_alns_simplex(x) = x.Algorithm in ["ALNS fast", "ALNS balanced", "ALNS thorough"] && x.Generator == "Simplex"
time_alns_planted(x) = x.Algorithm in ["ALNS fast", "ALNS balanced", "ALNS thorough"] && x.Generator == "Planted"

robot_simplex(x) = x.Generator == "Simplex"
robot_planted(x) = x.Generator == "Planted"

function main()

    df = CSV.read("benchmarks.csv", DataFrame)
    time_gens = [
        time_greedy_simplex,
        time_greedy_planted,
        time_alns_simplex,
        time_alns_planted    
    ]

    robot_gens = [
        robot_simplex,
        robot_planted
    ]

    for gen in time_gens
        p = plot_filter(df, gen, true)
        savefig(p, "$(nameof(gen)).png")
    end

    for gen in robot_gens
        p = plot_filter(df, gen, false)
        savefig(p, "$(nameof(gen)).png")
    end
end

main()