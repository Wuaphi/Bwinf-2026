package aufgabe3
import pq "core:container/priority_queue"
import "core:slice"
import "core:os"
import "core:fmt"
import "core:strings"
import "core:strconv"

Mode :: struct {
    cost : int,

    // Path technically reversed in practice.
    path : []^Factory
}

Factory :: struct {
    firm : int,
    id : int,

    conn : [dynamic]^Factory,
    dists : [dynamic]int,
    modes : [3]Mode,

    // temp for dijkstra:
    add_dist : int,
    came_from : ^Factory,
    final_vers : int,
    dist_vers : int
}

Problem :: struct {
    factories : []Factory,
    firm_loc : []int,
    firm_size : []int,

    allowed_length : int
}

Cost :: #type proc(^Factory) -> int
has_cost :: proc(f : ^Factory) -> int {
    return f.add_dist + f.modes[0].cost
}
will_cost :: proc(f : ^Factory) -> int {
    return f.add_dist + max(f.modes[1].cost, f.modes[2].cost)
}
now_cost :: proc(f : ^Factory) -> int {
    if f.came_from == nil {
        return max(int)
    }
    return f.add_dist + f.modes[0].cost
}

aufgabe3 :: proc(p : ^Problem) {

    search_vers := 0

    for i := len(p.firm_loc) - 1 ; i >= 0 ; i -= 1 {
        
        // find positions of current firm
        start := p.firm_loc[i]
        end := start + p.firm_size[i]

        start2 := end
        end2 := len(p.factories)
        next_size := 1

        if i != len(p.firm_loc) - 1 {
            end2 = p.firm_loc[i + 1] + p.firm_size[i + 1]
            next_size = p.firm_size[i + 1]
        }

        for j in start..< end {
            fac := &p.factories[j]
            search_vers += 1
            
            dijkstra(
                fac,
                next_size,
                1,
                search_vers
            )

            fac.modes[0] = minimizer(p.factories[start2:end2], fac, has_cost)
            fac.modes[1] = minimizer(p.factories[start2:end2], fac, will_cost)
        }

        // The starting node needs no now strike calculation.
        if i == 0 {continue}

        for j in start..<end {
            fac := &p.factories[j]
            search_vers += 1

            dijkstra(
                fac,
                p.firm_size[i],
                0,
                search_vers
            )

            fac.modes[2] = minimizer(p.factories[start:end], fac, now_cost)
        }
    }
}

minimizer :: proc(candi : []Factory, start : ^Factory, cost : Cost) -> Mode {
    min := max(int)
    loc : ^Factory = nil

    for i in 0..<len(candi) {
        // check if not reachable (should not happen, but for safety)
        if candi[i].final_vers != start.final_vers {continue}
        

        cos := cost(&candi[i])

        if cos < min {
            min = cos
            loc = &candi[i] 
        }
    }
    if min == max(int) {
        fmt.println("Keine erreichbaren Werke einer Firma!")
        os.exit(1)
    }

    route := make([dynamic]^Factory)
    for true {
        append(&route, loc)

        loc = loc.came_from
        if loc == nil {break}
    }

    return Mode{min, route[:]}
}

dijkstra :: proc(start : ^Factory, num, mode, vers : int) {
    found := 0

    // setup priority queue
    que : pq.Priority_Queue(^Factory)
    pq.init(
        &que,
        proc(a, b : ^Factory) -> bool {
            return a.add_dist < b.add_dist 
        },
        pq.default_swap_proc(^Factory),
        allocator = context.temp_allocator
    )
    defer free_all(context.temp_allocator)

    // fill first queue
    start.add_dist = 0
    start.dist_vers = vers
    start.came_from = nil
    pq.push(&que, start)

    // dijkstra
    for pq.len(que) > 0 {
        v := pq.pop(&que)

        if v.final_vers == vers {
            continue
        }
        v.final_vers = vers

        if v.firm == start.firm + mode {
            found += 1
        }

        // Early exit if found needed
        if found == num {break}

        for i in 0..<len(v.conn) {
            x := v.conn[i]
            new_dist := v.add_dist + v.dists[i]

            if x.dist_vers != vers || new_dist < x.add_dist{
                x.add_dist = new_dist
                x.came_from = v
                x.dist_vers = vers

                pq.push(&que, x)
            }
        }
    }
}

main_samples :: proc(write_to_file : bool = false) {
    curr_dir, _ := os.get_executable_directory(context.allocator)
    defer delete(curr_dir)

    eingaben_dir, _ := os.join_path([]string{curr_dir, "eingaben"}, context.allocator)
    ausgaben_dir, _ := os.join_path([]string{curr_dir, "ausgaben"}, context.allocator)

    defer delete(eingaben_dir)
    defer delete(ausgaben_dir)
    
    eingaben_handle := os.open(eingaben_dir) or_else panic("Eingaben nicht lesbar")
    defer os.close(eingaben_handle)
    file_info, _ := os.read_dir(eingaben_handle, 0, context.allocator) // 0 for all entries
    defer delete(file_info)

    for idx in 0..<len(file_info) {
        
        // get file content
        data, err := os.read_entire_file(file_info[idx].fullpath, context.allocator)
        defer delete(data)
        if err != nil {
            fmt.eprintln("ERROR: Fehler beim lesen der Datei: ", file_info[idx].name)
            continue
        }

        content := string(data)
        field := strings.fields(content)
        defer delete(field)

        // Redirect stdout if required.
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


        // setup basics
        p := new(Problem) 
        defer delete_problem(p)

        allowed_time := strconv.parse_int(field[0]) or_else panic("Falscher input")
        p.allowed_length = allowed_time

        num_firm := strconv.parse_int(field[1]) or_else panic("Falscher input")
        p.firm_loc = make([]int, num_firm + 1)
        p.firm_size = make([]int, num_firm + 1)

        pos := 1
        for i in 0..<num_firm{
            size := strconv.parse_int(field[2 + i]) or_else panic("Falscher input")
            if size <= 1 {panic("Firm with only 1 Factory. Impossible problem.")}

            p.firm_loc[i + 1] = pos
            p.firm_size[i + 1] = size
            pos += size
        }

        // setup T and S
        p.firm_loc[0] = 0
        p.firm_size[0] = 1
    
        p.factories = make([]Factory, pos + 1)
        p.factories[0].id = -1
        p.factories[0].firm = 0
        p.factories[0].conn = make([dynamic]^Factory)
        p.factories[0].dists = make([dynamic]int)

        p.factories[pos].id = -2
        p.factories[pos].firm = num_firm + 1
        p.factories[pos].conn = make([dynamic]^Factory)
        p.factories[pos].dists = make([dynamic]int)

        // Map factories to their firms
        filled := make([]int, num_firm + 1)
        defer delete(filled)
        id_to_loc := make([]int, pos + 1)
        defer delete(id_to_loc)

        firm_pos := num_firm + 3
        for i in 0..<(pos-1) {
            id := strconv.parse_int(field[firm_pos + 2 * i]) or_else panic("Falscher input")
            firm := strconv.parse_int(field[firm_pos + 2 * i + 1]) or_else panic("Falscher input")

            loc := p.firm_loc[firm] + filled[firm]
            p.factories[loc].id = id - 1
            p.factories[loc].firm = firm
            p.factories[loc].conn = make([dynamic]^Factory)
            p.factories[loc].dists = make([dynamic]int)

            id_to_loc[id - 1] = loc
            filled[firm] += 1
        }

        // Build connections
        conn_idx := firm_pos + (pos - 1) * 2
        conn_num := strconv.parse_int(field[conn_idx]) or_else panic("Falscher input")

        conn_pos := conn_idx + 1
        for i in 0..<conn_num {
            idx := i * 3 + conn_pos
            length := strconv.parse_int(field[idx + 2]) or_else panic("Falscher input")

            f1 := 0
            f2 := 0

            if field[idx] == "T" {
                f1 = len(p.factories) - 1
            } else if field[idx] != "S" {
                val := strconv.parse_int(field[idx]) or_else panic("Falscher input")
                f1 = id_to_loc[val - 1]
            }

            if field[idx + 1] == "T" {
                f2 = len(p.factories) - 1
            } else if field[idx + 1] != "S" {
                val := strconv.parse_int(field[idx+1]) or_else panic("Falscher input")
                f2 = id_to_loc[val - 1]
            }

            append(&p.factories[f1].conn, &p.factories[f2])
            append(&p.factories[f2].conn, &p.factories[f1])
            append(&p.factories[f1].dists, length)
            append(&p.factories[f2].dists, length)
        }

        aufgabe3(p)
        print_solution(p)
    } 
}

get_segment_time :: proc(path: []^Factory) -> int {
    t := 0

    for i := len(path) - 1; i > 0; i -= 1 {
        
        u := path[i]
        v := path[i-1]
        
        for j in 0..<len(u.conn) {
            if u.conn[j] == v {
                t += u.dists[j]
                break
            }
        }
    }

    return t
}

print_route_string :: proc(segments: [dynamic][]^Factory, is_alt: bool) {
    first_printed := false 
    
    for idx in 0..<len(segments) {
        seg := segments[idx]
        if len(seg) == 0 { continue }
        
        start_idx := len(seg) - 1

        if idx > 0 {
            // skip start after first happened
            start_idx -= 1
        }
        
        for i := start_idx; i >= 0; i -= 1 {
            node := seg[i]
            
            if first_printed {
                fmt.print(" ")
            }
            first_printed = true
            
            is_target := i == 0
            is_first := idx == 0 && i == len(seg) - 1
            
            if node.id == -1 {
                fmt.print("S")
            } else if node.id == -2 {
                fmt.print("T")
            } else {

                if is_target && !(is_alt && is_first) {
                    fmt.printf("[%d %d]", node.id + 1, node.firm)
                } else {
                    fmt.print(node.id + 1)
                }
            }
        }
    }
    fmt.println()
}

print_solution :: proc(p : ^Problem) {
    max_time := p.factories[0].modes[1].cost
    
    if max_time > p.allowed_length {
        fmt.println("UNMOEGLICH")
        return
    }
    fmt.println("MOEGLICH")
    fmt.println(max_time)
    fmt.println()

    norm_segs := make([dynamic][]^Factory)
    defer delete(norm_segs)

    curr := &p.factories[0]
    norm_time := 0
    
    for true {
        seg := curr.modes[1].path
        append(&norm_segs, seg)
        norm_time += get_segment_time(seg)
        
        curr = seg[0]
        if curr.id == -2 {break}
    }

    fmt.println(norm_time)
    print_route_string(norm_segs, false)

    cumul_time := 0
    curr = &p.factories[0]

    for true {
        seg := curr.modes[1].path
        cumul_time += get_segment_time(seg)
        curr = seg[0]

        if curr.id == -2 {break}

        alt_segs := make([dynamic][]^Factory)
        defer delete(alt_segs)

        alt_time := cumul_time
        
        strike_seg := curr.modes[2].path
        append(&alt_segs, strike_seg)
        alt_time += get_segment_time(strike_seg)

        alt_curr := strike_seg[0]

        for true {
            if alt_curr.id == -2 {break}

            norm_seg := alt_curr.modes[1].path
            append(&alt_segs, norm_seg)
            alt_time += get_segment_time(norm_seg)
            alt_curr = norm_seg[0]
        }

        fmt.println(alt_time)
        print_route_string(alt_segs, true)
    }

    fmt.println()
}

delete_problem :: proc(p : ^Problem) {
    for f in p.factories {
        delete(f.conn)
        delete(f.dists)

        for i in 0..<3 {
            delete(f.modes[i].path)
        }
    }

    delete(p.factories)
    delete(p.firm_loc)
    delete(p.firm_size)

    free(p)
}

main :: proc() {
    main_samples(true)
}