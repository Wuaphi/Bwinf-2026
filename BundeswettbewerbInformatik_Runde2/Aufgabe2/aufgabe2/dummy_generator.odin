package aufgabe2
import "core:math"
import "core:math/rand"
import "core:math/noise"
import "core:fmt"

disk_sample_tries :: 30
guided_tries :: 40
guided_dist_weight :: 2
guided_basic_weight :: 1

GridKey :: [2]int
disk_status :: struct {
    final : []Pos,
    active : ^[dynamic]int,
    grid : ^map[GridKey]Pos,

    pos : int,
    grid_length : f64,

    min : f64,
    max : f64
}

rand_circ :: proc() -> Pos {
    angle : f64 = 2 *  math.PI * rand.float64()
    y, x := math.sincos(angle)
    return Pos{x, y}
}

get_grid_key :: proc(stat : disk_status, p : Pos) -> GridKey {
    return GridKey{
        int(math.floor(p[0] / stat.grid_length)),
        int(math.floor(p[1] / stat.grid_length))
    }
}

has_grid_space :: proc(stat : disk_status, p : Pos) -> bool {
    sqr_min := stat.min * stat.min

    p_grid := get_grid_key(stat, p)
    if p_grid in stat.grid {return false}

    to_check := math.ceil(stat.min / stat.grid_length)

    for x in -to_check..=to_check {
        for y in -to_check..=to_check {
            gpos := GridKey{int(x), int(y)} + p_grid

            if !(gpos in stat.grid) {continue}
            if _dist(stat.grid[gpos], p) <= sqr_min {return false}  
        }
    }

    return true
}

disk_sample_step :: proc(stat : disk_status, idx : int, offset : f64 = 0.000001) -> bool {
    start := stat.final[stat.active[idx]]

    for _ in 0..<disk_sample_tries {
        scalar := rand.float64_range(stat.min + offset, stat.max)
        candidate := rand_circ() * scalar + start

        if !has_grid_space(stat, candidate) {continue}
        p_grid := get_grid_key(stat, candidate)

        stat.grid[p_grid] = candidate
        stat.final[stat.pos] = candidate
        append(stat.active, stat.pos)

        return true   
    }

    unordered_remove(stat.active, idx)
    return false
}

anchor_gen :: proc(robot_num : int, battery : f64) -> []Pos {
    active := make([dynamic]int, 1, robot_num)
    grid := make(map[GridKey]Pos, robot_num)

    defer delete(active)
    defer delete(grid)

    stat := disk_status{
        make([]Pos, robot_num),             // final
        &active,                            // active
        &grid,                              // grid
        1,                                  // pos
        (battery/2) / math.SQRT_TWO,        // grid_length
        (battery/2),                        // min
        (battery/2) * 1.2                   // max
    }
    stat.grid[GridKey{0,0}] = Pos{0, 0}
    
    for stat.pos < robot_num {

        for true {
            // rare edge case:
            if len(stat.active) == 0 {
                append(stat.active, rand.int_max(stat.pos))
            }

            idx := rand.int_range(0, len(stat.active))
            if disk_sample_step(stat, idx) {break}
        }

        stat.pos += 1
    }

    return stat.final
}

ellipse_point :: proc(p1, p2 : Pos, insertion : f64) -> Pos {
    
    d := dist(p1, p2)

    if d == 0 {
        return p1 + rand_circ() * (insertion / 2)
    }
    
    // find axises defining ellipse
    focal_dist : f64 = d / 2
    axis : f64 = (d + insertion) / 2
    perp_axis := math.sqrt(axis * axis - focal_dist * focal_dist)

    // sample random point on ellipse
    org_p := rand_circ() * Pos{axis, perp_axis}
    
    // readjust 
    center := (p1 + p2) / 2
    ux := (p1[0] - p2[0]) / d 
    uy := (p1[1] - p2[1]) / d

    rot_mat := matrix[2, 2]f64{
        ux, -uy,
        uy, ux
    }

    return center + rot_mat * org_p
}
guided_point :: proc(anchor, p2, c : Pos, insertion : f64) -> Pos {
    scores : [guided_tries]f64
    points : [guided_tries]Pos

    for i in 0..<guided_tries {
        points[i] = ellipse_point(anchor, p2, insertion)
        d := dist(points[i], c)
        scores[i] = math.pow(d, guided_dist_weight) + dist(points[i], anchor)
    }

    j := weighted_choose(scores[:])
    return points[j]
}

Float_Safety :: 0.00001

planted_gen :: proc(tree_num : int, robot_num : int, battery : f64) -> []Pos {
    if (tree_num / robot_num) > 10 {
        fmt.eprintln("WARNING: tree to robot ratio is unstable over 10")
    } 
    
    trees := make([]Pos, tree_num)
    
    anchors := anchor_gen(robot_num, battery)
    defer delete(anchors)
    copy(trees[0:robot_num], anchors)

    lengths := make([]int, robot_num)
    defer delete(lengths)
    
    rem_tree := tree_num - robot_num
    for rem_tree > 0 {
        pos := rand.int_range(0, robot_num)
        lengths[pos] += 1
        rem_tree -= 1
    }

    pos := robot_num

    for i in 0..<robot_num {
        anchor := anchors[i]
        
        last_p := anchor
        pos_sum := anchor

        usage := make([]f64, lengths[i])
        for j in 0..<lengths[i] {
            usage[j] = rand.float64() + guided_basic_weight
        }
        usage_sum := math.sum(usage)

        for j in 0..<lengths[i] {

            centroid := anchor
            if j > 0 {
                centroid = pos_sum / f64(j+1)
            }
            
            p := guided_point(
                anchor, 
                last_p,
                centroid,
                (usage[j] / (usage_sum + Float_Safety)) * battery,
            )

            trees[pos] = p
            last_p = p

            pos_sum += p
            pos += 1
        }

    }

    return trees
}

freq_mul :: 2
basic_density :: 0.4
min_mul :: 0.1
max_mul :: 0.2

simplex_gen :: proc(tree_num : int, battery : f64 = 10) -> []Pos {
    active := make([dynamic]int, 1, tree_num)
    grid := make(map[GridKey]Pos, tree_num)

    defer delete(active)
    defer delete(grid)

    grid_length := (battery * basic_density * min_mul) / math.SQRT_TWO

    stat := disk_status{
        make([]Pos, tree_num),    // final
        &active,                  // active
        &grid,                    // grid
        1,                        // pos
        grid_length,              // grid_length
        0,                        // min
        0                         // max
    }
    stat.grid[GridKey{0,0}] = Pos{0, 0}

    seed := rand.int63()
    freq := 1 / (battery * freq_mul)

    for stat.pos < tree_num {

        for true {
            // rare edge case. 
            if len(stat.active) == 0 {
                append(stat.active, rand.int_max(stat.pos))
            }
            
            idx := rand.int_range(0, len(stat.active))
            p := stat.final[stat.active[idx]]
            n := ((f64(noise.noise_2d(seed, p * freq)) + 1) / 2) * (1 - basic_density) + basic_density

            stat.min = battery * n * min_mul
            stat.max = battery * n * max_mul

            if disk_sample_step(stat, idx) {break}
        }

        stat.pos += 1
    }

    return stat.final
}
