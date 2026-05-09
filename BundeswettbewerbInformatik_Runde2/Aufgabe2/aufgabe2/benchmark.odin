package aufgabe2
import "core:time"
import "core:os"
import "core:fmt"
import "core:math/rand"

Alg :: struct {
    name : string,
    alg : solver
}

solver :: #type proc([]Pos, f64) -> ^Garden
greedy_wrapper :: proc(f : []Pos, battery : f64) -> ^Garden  {
    return construct_far_seed(f, battery, route_ci)
}
two_opt_wrapper :: proc(f : []Pos, battery : f64) -> ^Garden  {
    return construct_far_seed(f, battery, route_ci_2opt)
}
alns_fast_wrapper :: proc(f : []Pos, battery : f64) -> ^Garden {
    i := construct_far_seed(f, battery, route_ci_2opt)
    conf := build_alns_conf(len(i.tree), .fast)
    
    defer delete_alns_conf(conf)
    defer delete_garden(i)

    return alns(i, conf)
}
alns_balanced_wrapper :: proc(f : []Pos, battery : f64) -> ^Garden {
    i := construct_far_seed(f, battery, route_ci_2opt)
    conf := build_alns_conf(len(i.tree), .balanced)

    defer delete_alns_conf(conf)
    defer delete_garden(i)

    return alns(i, conf)
}
alns_thorough_wrapper :: proc(f : []Pos, battery : f64) -> ^Garden {
    i := construct_far_seed(f, battery, route_ci_2opt)
    conf := build_alns_conf(len(i.tree), .thorough)

    defer delete_alns_conf(conf)
    defer delete_garden(i)

    return alns(i, conf)
}

benchmark :: proc(input : []Pos, b : f64, a : Alg) -> (int, f64) {
    sw : time.Stopwatch

    time.stopwatch_start(&sw)
    
    g := a.alg(input, b)
    defer delete_garden(g)
    
    time.stopwatch_stop(&sw)

    dur := time.duration_milliseconds(time.stopwatch_duration(sw))
    res := len(g.routes)

    return res, dur
}

benchmarks :: proc(path : string = "benchmarks.csv") {

    algorithms := [?]Alg{
        {"Greedy", greedy_wrapper},
        {"Greedy + 2opt", two_opt_wrapper},
        {"ALNS fast", alns_fast_wrapper},
        {"ALNS balanced", alns_balanced_wrapper},
        {"ALNS thorough", alns_thorough_wrapper}
    }

    sizes : [500]int
    sizes[0] = 20
    for i in 1..<len(sizes) {
        sizes[i] = sizes[i-1] + 20
    }

    tries := 100
    battery : f64 = 10
    planted_divisor := 6

    thorough_thresh := 500
    balanced_thresh := 5_000

    // binary flags: create, clean and 
    handle, err := os.open(path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, os.Permissions_All)
    defer os.close(handle)
    
    if err != nil {
        fmt.eprintln("ERROR: Opening benchmark file")
        os.exit(1)
    }
    fmt.fprint(handle, "Algorithm,Generator,Size,Robots,Runtime\n")

    simplex_res := make([]int, len(algorithms))
    simplex_dur := make([]f64, len(algorithms))

    defer delete(simplex_res)
    defer delete(simplex_dur)

    for size in sizes {
        for t in 0..<tries {
            minimum := size / planted_divisor

            sample1 := simplex_gen(size)
            sample2 := planted_gen(size, minimum, battery)

            defer delete(sample1)
            defer delete(sample2)

            for i in 0..<len(algorithms) {

                if size > thorough_thresh && algorithms[i].name == "ALNS thorough" {
                    simplex_res[i] = max(int)
                    continue
                }
                if size > balanced_thresh && algorithms[i].name == "ALNS balanced" {
                    simplex_res[i] = max(int)
                    continue
                }

                simplex_res[i], simplex_dur[i] = benchmark(sample1, battery, algorithms[i])
                pres, pdur := benchmark(sample2, battery, algorithms[i])

                fmt.fprintf(
                    handle, 
                    "%s,Planted,%d,%d,%f\n", 
                    algorithms[i].name, 
                    size, 
                    pres - minimum, 
                    pdur
                )
            }

            found_minimum := max(int)
            for i in 0..<len(algorithms) {
                if simplex_res[i] < found_minimum {
                    found_minimum = simplex_res[i]
                }
            }

            for i in 0..<len(algorithms) {
                if simplex_res[i] == max(int) {continue}

                fmt.fprintf(
                    handle, 
                    "%s,Simplex,%d,%d,%f\n", 
                    algorithms[i].name, 
                    size, 
                    simplex_res[i] - found_minimum, 
                    simplex_dur[i]
                )
            }
        }

        fmt.println("Finished size: ", size)
    }
} 

