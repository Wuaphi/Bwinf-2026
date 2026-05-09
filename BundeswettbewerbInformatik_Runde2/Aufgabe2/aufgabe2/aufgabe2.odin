package aufgabe2
import "core:math"
import "core:slice"
import "core:container/queue"
import "core:os"
import "core:strings"
import "core:strconv"
import "core:fmt"
import "core:time"
import "core:math/rand"

Pos :: [2]f64
Pair :: [2]int

Cache :: struct{
    lpair : ^Linked_Pairs,
    dist : f64
}

Garden :: struct{
    tree : []Pos,
    edges : []^Linked_Pairs,

    rout_pl : ^Pool,
    routes : [dynamic]^Route,
    
    tot_size : f64,
    battery : f64
}

Indices_c :: struct{
    center : Pos,
    values : []Pos
}

remove_watered :: proc(region : ^[dynamic]int, is_watered : []bool) {
    for i := len(region^)-1 ; i >= 0 ; i -= 1  {
        if is_watered[region^[i]] {unordered_remove(region, i)}
    }
}

cheapest_insert :: proc(pl : ^Pool, c : []Cache, reml : ^f64) -> (^Linked_Pairs, ^Linked_Pairs, bool) {
        
    // Find tree to add
    lowest : f64 = math.inf_f64(1)
    t : int

    for i in 0..<len(c) {
        if c[i].dist < lowest {
            lowest = c[i].dist
            t = i
        }
    }

    // Check if not possible to add
    // Implicitely checks if all trees have been included
    if lowest > reml^ {
        return nil, nil, true
    }

    newp := insert_edge(pl, c[t].lpair, t)
    reml^ -= lowest
    c[t].dist = math.inf_f64(1)

    return newp, c[t].lpair, false
}
cheap_cache_update :: proc(f : []^Pos, c : []Cache, newp, oldp : ^Linked_Pairs) {
        
    for i in 0..<len(c) {

        // Hinder overwriting pointer, to free it later.
        if c[i].dist == math.inf_f64(1) {
            continue
        }

        // Calculate dist to new pairs
        dist1 := detour_cost(
            get_pair(f, newp.pair), 
            idx(f, i)
        )
        dist2 := detour_cost(
            get_pair(f, newp.next.pair), 
            idx(f, i)
        )  
        
        /* 
        Guarantee picking new if favourite destroyed
        Only picking from new Pairs to maintain O(N) cache updating.
        Only a Heuristic, but should work most of the times as the two new edges are geometrically close.
        */

        // underlaying memory of oldp may be already dead, but oldp is only a pointer...: No use-after-free bug! 
        // Even if it would be replaced, I only compare pointers that don't change.

        if c[i].lpair == oldp {
            c[i].dist = math.inf_f64(1)
        }

        mini := min(c[i].dist, dist1, dist2)
        if mini == dist1 {
            c[i].lpair = newp
            c[i].dist = dist1
        } else if mini == dist2 {
            c[i].lpair = newp.next
            c[i].dist = dist2
        }
    }
}
rebuild_cache :: proc(f : []^Pos, c : []Cache, edges : ^Linked_Pairs) {
    for i in 0..<len(c) {

        // check if used already
        if c[i].dist == math.inf_f64(1) {continue}

        fav : ^Linked_Pairs
        d := math.inf_f64(1)

        curr := edges
        for true {

            newd := detour_cost(
                get_pair(f, curr.pair),
                idx(f, i)
            )

            if newd < d {
                fav = curr
                d = newd
            }
            
            curr = curr.next
            if curr == edges {break}
        }

        c[i].dist = d
        c[i].lpair = fav
    }
}

router :: #type proc(^Pool, []^Pos, int, f64) -> (^Route, f64)
route_ci :: proc(pl : ^Pool, f : []^Pos, start : int, l : f64) -> (^Route, f64) {
    r := init_route(pl, start)
    
    c := make([]Cache, len(f))
    defer delete(c)
    for i in 0..<len(f) {
        c[i] = Cache{
            r.head, 
            detour_cost(
                get_pair(f, r.head.pair), 
                idx(f, i)
        )}
    }

    c[start].dist = math.inf_f64(1)
    reml := l

    for true {
        newp, oldp, stop := cheapest_insert(pl, c, &reml)
        if stop {break}

        cheap_cache_update(f, c, newp, oldp)
    }

    return r, reml
}
route_ci_2opt :: proc(pl : ^Pool, f : []^Pos, start : int, l : f64) -> (^Route, f64) {
    r := init_route(pl, start)
    
    c := make([]Cache, len(f))
    defer delete(c)
    for i in 0..<len(f) {
        c[i] = Cache{
            r.head, 
            detour_cost(
                get_pair(f, r.head.pair), 
                idx(f, i)
        )}
    }

    c[start].dist = math.inf_f64(1)
    reml := l

    for true {
        newp, oldp, stop := cheapest_insert(pl, c, &reml)
        if stop {
            change := two_opt(f, r.head)
            if change == 0 {break}
            
            reml += change
            rebuild_cache(f, c, r.head)
            
            continue
        }
        
        cheap_cache_update(f, c, newp, oldp)
    }

    return r, reml
}

construct_far_seed :: proc(f : []Pos,  battery : f64, heur : router) -> ^Garden {

    tree := build_tree(f)
    pl := init_pool(len(tree))

    g := new_clone(Garden{
        tree,                           // tree  
        make([]^Linked_Pairs, len(f)),  // edges
        pl,                             // rout_pl
        make([dynamic]^Route),          // routes
        0,                              // tot_size
        battery                         // battery
    })

    is_watered := make([]bool, len(f))
    defer delete(is_watered)
    indices := make([]int, len(f))
    defer delete(indices)

    for i in 0..<len(f) {
        indices[i] = i
    }

    center := mass_midpoint(f)

    // odin has no closures ):
    // context is the only way
    context.user_ptr = &Indices_c{center, tree}
    slice.sort_by(
        indices,
        proc(i, j : int) -> bool {
            s := (cast(^Indices_c)context.user_ptr)^
            return _dist(s.values[i], s.center) > _dist(s.values[j], s.center) // flipped for descending order
        }
    )

    most_dist := 0

    for most_dist < len(tree) {

        root := tree[indices[most_dist]]

        // only pick nearest
        region := tree_circle_search(
            tree, 
            root, 
            battery/2,
            context.temp_allocator
        )
        remove_watered(&region, is_watered)

        space := make(
            []^Pos, 
            len(region),
            context.temp_allocator
        )

        // realize space
        root_idx := -1
        for i in 0..<len(region) {
            j := region[i]
            space[i] = &tree[j]

            if j == indices[most_dist] {
                root_idx = i 
            }
        }

        // generate a root
        route, reml := heur(pl, space, root_idx, battery)

        // update watered
        curr := route.head
        length := 0
        for true {
            // globalize the indices.
            global_p1 := region[curr.pair[0]]
            global_p2 := region[curr.pair[1]]
            curr.pair = Pair{global_p1, global_p2}

            is_watered[global_p1] = true

            // values safekeeping
            length += 1
            g.edges[global_p2] = curr

            curr = curr.next
            if curr == route.head {break}
        }

        // find next most distant
        for true {
            most_dist += 1
            if most_dist >= len(f) {break}
            if !is_watered[indices[most_dist]] {break} 
        }

        append(&g.routes, route)
        route.length = length
        route.size = battery - reml
        route.idx = len(g.routes) - 1
        g.tot_size += battery - reml

        free_all(context.temp_allocator)
    }

    return g
}

main_samples :: proc(gprint : bool = false, write_to_file : bool = false, alns_its : int = 1) {
    curr_dir, err := os.get_executable_directory(context.allocator)
    defer delete(curr_dir)

    eingaben_dir, err2 := os.join_path([]string{curr_dir, "eingaben"}, context.allocator)
    ausgaben_dir, err3 := os.join_path([]string{curr_dir, "ausgaben"}, context.allocator)

    defer delete(eingaben_dir)
    defer delete(ausgaben_dir)
    
    eingaben_handle := os.open(eingaben_dir) or_else panic("Eingaben nicht lesbar")
    defer os.close(eingaben_handle)
    file_info, err5 := os.read_dir(eingaben_handle, 0, context.allocator) // 0 for all entries
    defer os.file_info_slice_delete(file_info, context.allocator)

    for idx in 0..<len(file_info) {
        data, err := os.read_entire_file(file_info[idx].fullpath, context.allocator)
        defer delete(data)

        if err != nil {
            fmt.eprintln("ERROR: Fehler beim lesen der Datei: ", file_info[idx].name)
            continue
        }

        // setup file streaming.
        content := string(data)
        ausgaben_handle : ^os.File

        if write_to_file {
            ausgaben_path, _ := os.join_path(
                []string{ausgaben_dir, file_info[idx].name}, 
                context.allocator
            )
            defer delete(ausgaben_path)

            ausgaben_handle, err2 := os.open(ausgaben_path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, os.Permissions_All)

            if err2 != nil {
                fmt.eprintln("ERROR: Fehler beim erzeugen des Outputs: ", file_info[idx].name)
                continue
            }

            os.stdout = ausgaben_handle
        }
        defer os.close(ausgaben_handle)



        // read input file
        field := strings.fields(content)
        defer delete(field)
        trees := make([]Pos, (len(field) - 2) / 3)
        defer delete(trees)

        battery, ok2 := strconv.parse_int(field[0])
        if !ok2 {
            fmt.eprintln("ERROR: Fehler beim lesen der Datei: ", file_info[idx].name)
            continue
        }

        for i in 0..<len(trees) {
            x, ok3 := strconv.parse_int(field[i * 3 + 3])
            if !ok3 {
                fmt.eprintln("ERROR: Fehler beim lesen der Datei: ", file_info[idx].name)
                continue
            }
            y, ok4 := strconv.parse_int(field[i * 3 + 4])
            if !ok4 {
                fmt.eprintln("ERROR: Fehler beim lesen der Datei: ", file_info[idx].name)
                continue
            }
            
            trees[i] = Pos{
                f64(x),
                f64(y)
            }
        }

        // calculate gardens
        standard := construct_far_seed(trees, f64(battery), route_ci)
        improved := construct_far_seed(trees, f64(battery), route_ci_2opt)
        defer delete_garden(standard)
        defer delete_garden(improved)


        conf1 := build_alns_conf(len(improved.tree), .fast)
        defer delete_alns_conf(conf1)
        best_g1 : ^Garden 
        defer delete_garden(best_g1)

        if alns_its > 0 {
            best_g1 = alns(improved, conf1)

            for i in 1..<alns_its {
                newg := alns(improved, conf1)
                if len(newg.routes) < len(best_g1.routes) {
                    delete_garden(best_g1)
                    best_g1 = newg
                } else {
                    delete_garden(newg)
                }
            }
        }

        //fmt.println("fast finished")

        conf2 := build_alns_conf(len(improved.tree), .balanced)
        defer delete_alns_conf(conf2)
        best_g2 : ^Garden
        defer delete_garden(best_g2)

        if alns_its > 0 {
            best_g2 = alns(improved, conf2)

            for i in 1..<alns_its {
                newg := alns(improved, conf2)
                if len(newg.routes) < len(best_g2.routes) {
                    delete_garden(best_g2)
                    best_g2 = newg
                } else {
                    delete_garden(newg)
                }
            }
        }

        //fmt.println("balanced finished")

        conf3 := build_alns_conf(len(improved.tree), .thorough)
        defer delete_alns_conf(conf3)
        best_g3 : ^Garden
        defer delete_garden(best_g3)


        if alns_its > 0 {
            best_g3 = alns(improved, conf3)

            for i in 1..<alns_its {
                newg := alns(improved, conf3)
                if len(newg.routes) < len(best_g3.routes) {
                    delete_garden(best_g3)
                    best_g3 = newg
                } else {
                    delete_garden(newg)
                }
            }
        }

        validate_garden(standard)
        validate_garden(improved)
        if alns_its > 0 {
            validate_garden(best_g1)
            validate_garden(best_g2)
            validate_garden(best_g3)
        }

        fmt.println("Kleinste Anzahlen von Roboter gefunden:")
        fmt.println("greedy: ", len(standard.routes))
        fmt.println("greedy + 2opt: ", len(improved.routes))
        if alns_its > 0 {
            fmt.println("ALNS fast: ", len(best_g1.routes))
            fmt.println("ALNS balanced: ", len(best_g2.routes))
            fmt.println("ALNS thorough: ", len(best_g3.routes))
        }

        best := standard
        if len(improved.routes) < len(best.routes) {best = improved}
        
        if alns_its > 0 { 
            if len(best_g1.routes) < len(best.routes) {best = best_g1}
            if len(best_g2.routes) < len(best.routes) {best = best_g2}
            if len(best_g3.routes) < len(best.routes) {best = best_g3}
        }

        fmt.println("So hat der beste Algorithmus ein Minimum von ", len(best.routes), " gefunden.")

        if gprint {
            fmt.println("Seine Lösung sieht so aus: ")
            print_garden(best)
        }
    } 
}

main :: proc() {

    args := os.args

    if len(args) > 3 {
        panic("ERROR: Zu viele Argumente!")
    }

    if len(args) <= 1 {
        main_samples(false, false, 0)
        return
    }

    if len(args) == 2 {
        num := strconv.parse_int(args[1]) or_else panic("ERROR: Argument keine Zahl!")
        main_samples(false, false, num)
    } else {
        num := strconv.parse_int(args[2]) or_else panic("ERROR: Argument keine Zahl!")

        if args[2] != "to_file" {
            fmt.println("ERROR: Falsche Argumente")
        } else {
            main_samples(true, true, num)
        }
    } 
    //benchmarks()
}