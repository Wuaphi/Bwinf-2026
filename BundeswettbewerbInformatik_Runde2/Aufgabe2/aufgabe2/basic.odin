package aufgabe2
import "core:math/rand"
import "core:math"
import "core:os"
import "core:fmt"


dist :: proc(x, y : Pos) -> f64 {
    x_dif := x[0] - y[0]
    y_dif := x[1] - y[1]
    return math.sqrt(x_dif * x_dif + y_dif * y_dif)
}

_dist :: proc(x, y : Pos) -> f64 {
    x_dif := x[0] - y[0]
    y_dif := x[1] - y[1]
    return x_dif * x_dif + y_dif * y_dif
}

idx1 :: proc(p : []^Pos, i : int) -> Pos {return p[i]^} 
idx2 :: proc(p : []Pos, i : int) -> Pos {return p[i]}
idx :: proc{idx1, idx2}
 
get_pair :: proc(x : []^Pos, p : Pair) -> [2]Pos {
    return [2]Pos{idx(x, p[0]), idx(x, p[1])}
}

detour_cost :: proc(x : [2]Pos, y : Pos) -> f64 {
    return dist(x[0], y) + dist(x[1], y) - dist(x[0], x[1])
}

mass_midpoint :: proc(x : []Pos) -> Pos {
    out : Pos = {0, 0}
    for y in x {
        out[0] += y[0]
        out[1] += y[1]
    }
    out /= f64(len(x))

    return out
}

weighted_choose :: proc(x : []f64) -> int {
    sum := math.sum(x)
    r := rand.float64_range(0, sum)
    
    chosen : int
    for i in 0..<len(x) {
        r -= x[i]
        if r <= 0 {
            return i
        } 
    }

    // Just for safety
    return len(x) - 1
}

validate_garden :: proc(g : ^Garden) {
    max : f64 = 0
    allow_err := 0.0001 // floating point error accumulates

    for rout in g.routes {
        curr := rout.head
        size : f64= 0

        for true {

            size += dist(g.tree[curr.pair[0]], g.tree[curr.pair[1]])

            curr = curr.next
            if curr == rout.head {break}
        }

        if size < rout.size - allow_err || size > rout.size + allow_err {
            fmt.println("FALSE SIZE")
            fmt.println(size)
            fmt.println(rout.size)
        } 

        if size > max {
            max = size
        }
    } 

    if max > g.battery {
        fmt.println("TOO LARGE")
        fmt.println(max)
        fmt.println(g.battery)
    }
}

print_route :: proc(f : []Pos, r : ^Route) {

    curr := r.head
    for true {
        fmt.print(f[curr.pair[1]])
        fmt.print(" -> ")

        curr = curr.next
        if curr == r.head {break}
    }

    fmt.print(f[r.head.pair[1]])
    fmt.print("    size: ", r.size, "\n")
}

print_garden :: proc(g : ^Garden) {
    
    for i in 0..<len(g.routes) {
        fmt.print("Route", i + 1, ": ")
        print_route(g.tree, g.routes[i])
    }

}