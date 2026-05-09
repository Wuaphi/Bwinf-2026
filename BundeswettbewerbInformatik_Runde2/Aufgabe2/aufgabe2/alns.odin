package aufgabe2
import "core:slice"
import "core:math/rand"
import "core:math"
import "core:fmt"
import "core:time"

rem_op :: #type proc(^Garden) -> []int
add_op :: #type proc(^Garden, []int)

Alns_conf :: struct {
    rem : []rem_op,
    add : []add_op,

    Wupdate : int,
    react_fact : f64,
    patience : int,
    time_limit : time.Duration,

    its : int,
    temp_mul : f64
}

SA_conf :: struct{
    temp : [2]f64,
    decay : [2]f64
}

Alns_vers :: enum{fast, balanced, thorough}
Weights :: struct {
    W : []f64,
    S : []int,
    N : []int
}


Regret2_cache :: struct{
    loc : int,
    region : []int,

    // Favs
    best : f64,
    sec_best : f64,
    fav : ^Linked_Pairs,
    sec_fav : ^Linked_Pairs
}
Worst_savings :: struct{
    sav : f64,
    noise_sav : f64,
    
    idx : int
}

Forest_Mul :: 5

delete_alns_conf :: proc(x : Alns_conf) {
    delete(x.rem)
    delete(x.add)
}

build_alns_conf :: proc(size : int, version : Alns_vers = .balanced) -> Alns_conf {
    out : Alns_conf

    switch version {
        case .fast:
            out.its = 500 + min(size, 1_000)

            out.Wupdate = 50
            out.react_fact = 0.2

            out.patience = 200
            out.time_limit = time.Minute

            out.temp_mul = 0.8

        case .balanced:
            out.its = 1_000 + min(10 * size, 5_000)

            out.Wupdate = 100
            out.react_fact = 0.1

            out.patience = 1_000
            out.time_limit = time.Minute * 10

            out.temp_mul = 1

        case .thorough:
            out.its = 10_000 + min(20 * size, 20_000)

            out.Wupdate = 200
            out.react_fact = 0.05
            
            out.patience = 5_000
            out.time_limit = time.Hour
            
            out.temp_mul = 1.2
    }

    out.rem = slice.clone([]rem_op{
        rand_rem,
        radius_rem,
        route_rem,
        worst_rem,
        worst_noise_rem,
        shortest_route_rem
    })

    out.add = slice.clone([]add_op{
        greedy_reinsert,
        greedy_noise_reinsert,
        regret2_reinsert
    })

    return out
}

// deletes two specific edges in a specific route
g_rem :: proc(g : ^Garden, p : ^Linked_Pairs) {

    if p == nil {return}
    if p.route.length == 1 {
        removed_idx := p.route.idx
        unordered_remove(&g.routes, removed_idx)

        // overwrite swapped routes idx
        // only if previously longer than 1
        if removed_idx < len(g.routes) {
            g.routes[removed_idx].idx = removed_idx
        }

        g.edges[p.pair[1]] = nil
        free_pair(g.rout_pl, p)
        delete_route(p.route)
        return
    }

    cost := detour_cost(
        {g.tree[p.pair[0]], g.tree[p.next.pair[1]]},
        g.tree[p.pair[1]]
    ) 

    p.route.length -= 1
    p.route.size -= cost

    g.tot_size -= cost 
    g.edges[p.pair[1]] = nil 

    newp := delete_edges(g.rout_pl, p)
    g.edges[newp.pair[1]] = newp
    return
}
// add a specific tree to a route
g_add :: proc(g : ^Garden, p : ^Linked_Pairs, ins : int) {

    // if no valid tree, create new route
    if p == nil {
        nr := init_route(g.rout_pl, ins)
        nr.idx = len(g.routes)

        append(&g.routes, nr)
        g.edges[ins] = nr.head
        return
    }
    
    cost := detour_cost(
        {g.tree[p.pair[0]], g.tree[p.pair[1]]},
        g.tree[ins]
    )

    p.route.length += 1
    p.route.size += cost
    g.tot_size += cost

    newp := insert_edge(g.rout_pl, p, ins)

    g.edges[ins] = newp
    g.edges[newp.next.pair[1]] = newp.next
}

rand_rem :: proc(g : ^Garden) -> []int {
    start := rand.choice(g.tree)
    forest := tree_circle_search(
        g.tree, 
        start, 
        g.battery * Forest_Mul,
        context.temp_allocator
    )

    rem := len(forest) / rand.int_range(4, 10)
    removed := make([]int, rem, context.temp_allocator)

    for counter in 0..<rem {
        i := rand.int_max(len(forest))
        removed[counter] = forest[i]

        g_rem(g, g.edges[forest[i]])
        unordered_remove(&forest, i)
    }

    return removed
}
radius_rem :: proc(g : ^Garden) -> []int {
    start := rand.choice(g.tree)
    forest := tree_circle_search(
        g.tree, 
        start, 
        g.battery * Forest_Mul,
        context.temp_allocator
    )
    rem := len(forest) / rand.int_range(4, 10)
    removed := make([]int, rem, context.temp_allocator)

    rad := rand.float64_range(
        g.battery/20, 
        g.battery/5
    )

    remrem := rem
    counter := 0

    for remrem > 0 {

        center := g.tree[rand.choice(forest[:])]
        region := tree_circle_search(
            g.tree, 
            center, 
            rad,
            context.temp_allocator
        )

        for i in 0..<len(region) {
            if g.edges[region[i]] == nil {continue}

            g_rem(g, g.edges[region[i]])
            removed[counter] = region[i]
            
            counter += 1
            remrem -= 1
            if remrem == 0 {break}
        }
    }

    return removed
}
route_rem :: proc(g : ^Garden) -> []int {
    start := rand.choice(g.tree)
    forest := tree_circle_search(
        g.tree, 
        start, 
        g.battery * Forest_Mul,
        context.temp_allocator
    )
    rem := len(forest) / rand.int_range(4, 10)
    removed := make([]int, rem, context.temp_allocator)

    remrem := rem
    counter := 0

    for remrem > 0 {
        i := rand.int_max(len(forest))
        curr := g.edges[forest[i]]
        unordered_remove(&forest, i)
        if curr == nil {continue}
        
        rout := curr.route

        size := min(remrem, rout.length)
        for _ in 0..<size {

            removed[counter] = curr.pair[1]
            g_rem(g, curr)

            curr = rout.head
            counter += 1
            remrem -= 1
        }

    }

    return removed
}
worst_rem :: proc(g : ^Garden) -> []int {
    start := rand.choice(g.tree)
    forest := tree_circle_search(
        g.tree, 
        start, 
        g.battery * Forest_Mul,
        context.temp_allocator
    )
    rem := len(forest) / rand.int_range(4, 10)
    removed := make([]int, rem, context.temp_allocator)

    savings := make(
        []Worst_savings, 
        len(forest),
        context.temp_allocator
    )

    for i in 0..<len(forest) {
        curr := g.edges[forest[i]]

        if curr.route.length == 1 {
            savings[i] = {math.inf_f64(1), 0, i}
            continue
        }

        cost := detour_cost(
            {g.tree[curr.pair[0]], g.tree[curr.next.pair[1]]},
            g.tree[forest[i]]
        )
        savings[i] = {cost,0, i}
    }

    slice.sort_by(
        savings,
        proc(a, b : Worst_savings) -> bool {
            return a.sav > b.sav
        }
    )

    for i in 0..<rem {
        idx := savings[i].idx
        curr := g.edges[forest[idx]]
        // g.edges can't be nil as it must be filled previously and we only remove uniquely.

        removed[i] = forest[idx]
        g_rem(g, curr)
    }

    return removed
}
worst_noise_rem :: proc(g : ^Garden) -> []int {
    start := rand.choice(g.tree)
    forest := tree_circle_search(
        g.tree, 
        start, 
        g.battery * Forest_Mul,
        context.temp_allocator
    )
    rem := len(forest) / rand.int_range(4, 10)
    removed := make([]int, rem, context.temp_allocator)

    savings := make(
        []Worst_savings, 
        len(forest),
        context.temp_allocator
    )

    for i in 0..<len(forest) {
        curr := g.edges[forest[i]]

        if curr.route.length == 1 {
            savings[i] = {math.inf_f64(1), math.inf_f64(1), i}
            continue
        }

        cost := detour_cost(
            {g.tree[curr.pair[0]], g.tree[curr.next.pair[1]]},
            g.tree[forest[i]]
        )
        rand_cost := cost * rand.float64_range(0.8, 1.2)

        savings[i] = {cost, rand_cost, i}
    }

    slice.sort_by(
        savings,
        proc(a, b : Worst_savings) -> bool {
            return a.noise_sav > b.noise_sav
        }
    )

    for i in 0..<rem {
        idx := savings[i].idx
        curr := g.edges[forest[idx]]
        // g.edges can't be nil as it must be filled previously and we only remove uniquely.

        removed[i] = forest[idx]
        g_rem(g, curr)
    }

    return removed
}
shortest_route_rem :: proc(g : ^Garden) -> []int {
    rem := min(len(g.tree) / rand.int_range(10, 30), 100)
    removed := make([]int, rem, context.temp_allocator)

    short := make(
        []^Route,
        len(g.routes),
        context.temp_allocator
    )
    copy(short, g.routes[:])
    slice.sort_by(
        short,
        proc(a, b : ^Route) -> bool {
            return a.length < b.length // ascending order for destroying shortest routse.
        }
    )

    counter := 0
    remrem := rem

    for r in short {
        size := min(remrem, r.length)
        curr := r.head

        for _ in 0..<size {    
            removed[counter] = curr.pair[1]
            g_rem(g, curr)

            curr = r.head
            counter += 1
            remrem -= 1
        }
    }

    return removed
}


greedy_reinsert :: proc(g : ^Garden, a : []int) {
    for i in a {
        best := math.inf_f64(1)
        loc : ^Linked_Pairs = nil

        region := tree_circle_search(
            g.tree, 
            g.tree[i], 
            g.battery/2,
            context.temp_allocator
        )

        for j in region {

            curr := g.edges[j]
            if curr == nil {continue}

            cost := detour_cost(
                {g.tree[curr.pair[0]], g.tree[curr.pair[1]]},
                g.tree[i]
            )

            rem := g.battery - curr.route.size

            if cost < best && cost <= rem {
                best = cost
                loc = curr
            }
        }

        
        g_add(g, loc, i)
    }

    free_all(context.temp_allocator)
}
greedy_noise_reinsert :: proc(g : ^Garden, a : []int) {
    for i in a {
        best := math.inf_f64(1)
        loc : ^Linked_Pairs = nil

        region := tree_circle_search(
            g.tree, 
            g.tree[i], 
            g.battery/2,
            context.temp_allocator
        )

        for j in region {

            curr := g.edges[j]
            if curr == nil {continue}

            cost := detour_cost(
                {g.tree[curr.pair[0]], g.tree[curr.pair[1]]},
                g.tree[i]
            )
            noisy_cost := cost * rand.float64_range(0.8, 1.2)

            rem := g.battery - curr.route.size

            if noisy_cost < best && cost <= rem {
                best = noisy_cost
                loc = curr
            }
        }

        
        g_add(g, loc, i)
    }

    free_all(context.temp_allocator)
}

regret2_cache_update :: proc(g : ^Garden, c : ^Regret2_cache, curr : ^Linked_Pairs) {       
    if curr == nil {return}

    cost := detour_cost(
        {g.tree[curr.pair[0]], g.tree[curr.pair[1]]},
        g.tree[c.loc]
    )
    rem := g.battery - curr.route.size

    if cost <= rem {
        // ensure not from the same route
        r0 : ^Route = nil
        if c.fav != nil {
            r0 = c.fav.route
        }

        if cost < c.best {
            // only push down when old best not from same route
            if curr.route != r0 {
                c.sec_fav = c.fav  
                c.sec_best = c.best   
            }

            c.fav = curr
            c.best = cost

            // if the same route as best, but worse than best, never add.
        } else if cost < c.sec_best && curr.route != r0 {
            c.sec_best = cost
            c.sec_fav = curr
        }
    }
}
regret2_reinsert :: proc(g : ^Garden, a : []int) {
    cache := make(
        [dynamic]Regret2_cache,
        len(a),
        context.temp_allocator
    )

    for i in 0..<len(a) {
        cache[i].loc = a[i]
        cache[i].region = tree_circle_search(
            g.tree, 
            g.tree[a[i]],
            g.battery/2,
            context.temp_allocator
        )[:]
    }

    last_route : ^Route = nil

    for len(cache) > 0 { 
        highest_regret : f64 = -1
        idx : int

        pre_stopped := false

        for i in 0..<len(cache) {

            // only at init true
            need_best := true
            need_sec := true

            if cache[i].fav != nil{
                need_best = last_route == cache[i].fav.route
            }
            if cache[i].sec_fav != nil {
                need_sec = last_route == cache[i].sec_fav.route
            }

            if need_best || need_sec || last_route == nil {
                cache[i].best = math.inf_f64(1)
                cache[i].sec_best = math.inf_f64(1)
                cache[i].fav = nil
                cache[i].sec_fav = nil

                for j in cache[i].region {
                    curr := g.edges[j]
                    regret2_cache_update(g, &cache[i], curr)
                }
            } else {

                curr := last_route.head

                for true {
                    regret2_cache_update(g, &cache[i], curr)
                    curr = curr.next
                    if curr == last_route.head {break}
                }

            }

            if cache[i].best == math.inf_f64(1) {
                idx = i
                pre_stopped = true
                break
            }

            reg := cache[i].sec_best - cache[i].best
            if reg > highest_regret {
                highest_regret = reg
                idx = i
            }
        }

        if !pre_stopped {
            last_route = cache[idx].fav.route
        }

        g_add(g, cache[idx].fav, cache[idx].loc)
        unordered_remove(&cache, idx)
    }

    free_all(context.temp_allocator)
}

rewrite_routes :: proc(pl_nw, pl_ol : ^Pool, rout_nw, rout_ol : ^[dynamic]^Route) {
    
    resize(&pl_nw.fr, len(pl_ol.fr))
    copy(pl_nw.fr[:], pl_ol.fr[:])

    if len(rout_nw) > len(rout_ol) {
        for i := len(rout_nw) - 1 ; i >= len(rout_ol) ; i -= 1 {
            delete_route(rout_nw[i])
        } 
    }
    resize(rout_nw, len(rout_ol))

    for i in 0..<len(rout_ol) {

        if rout_nw[i] == nil {
            rout_nw[i] = new(Route)
        }

        rout_nw[i].head = &pl_nw.pl[rout_ol[i].head.pool_idx]
        rout_nw[i].length = rout_ol[i].length
        rout_nw[i].size = rout_ol[i].size
        rout_nw[i].idx = i
    }

    for i in 0..<len(pl_ol.pl) {
        nw := &pl_nw.pl[i]
        ol := &pl_ol.pl[i]
 
        nw.pair = ol.pair
        nw.pool_idx = i
        if ol.next != nil && ol.prev != nil && ol.route.idx < len(rout_nw) {

            nw.next = &pl_nw.pl[ol.next.pool_idx]
            nw.prev = &pl_nw.pl[ol.prev.pool_idx]
            nw.route = rout_nw[ol.route.idx]

        }
    }
}
copy_garden :: proc(g : ^Garden) -> ^Garden {    
    pl := init_pool(len(g.tree))
    routes_copy := make([dynamic]^Route, len(g.routes))

    rewrite_routes(
        pl,
        g.rout_pl,  
        &routes_copy,
        &g.routes
    )

    tree := make([]Pos, len(g.tree))
    copy(tree[:], g.tree[:])

    edges := make([]^Linked_Pairs, len(g.edges))
    for i in 0..<len(g.edges) {
        if g.edges[i] == nil {
            edges[i] = nil
            continue
        }
        edges[i] = &pl.pl[g.edges[i].pool_idx]
    } 

    out := new_clone(Garden{
        tree,
        edges,
        pl,
        routes_copy,
        g.tot_size,
        g.battery
    })

    return out
}
// Doesn't copy tree
rewrite_garden :: proc(g_nw, g_ol : ^Garden) {
    rewrite_routes(
        g_nw.rout_pl,
        g_ol.rout_pl,
        &g_nw.routes,
        &g_ol.routes
    )

    for i in 0..<len(g_ol.edges) {
        if g_ol.edges[i] == nil {
            g_nw.edges[i] = nil
            continue
        }
        g_nw.edges[i] = &g_nw.rout_pl.pl[g_ol.edges[i].pool_idx]
    } 

    g_nw.tot_size = g_ol.tot_size
    g_nw.battery = g_ol.battery
}

alns_update :: proc(g : ^Garden, r : rem_op, a : add_op) {
    //remove
    unassigned := r(g)

    //add
    a(g, unassigned)
}
alns_cost :: proc(g : ^Garden) -> f64 {
    return f64(len(g.routes)) + (f64(g.tot_size) / (f64(len(g.routes)) * g.battery))
}

init_weights :: proc(l : int) -> ^Weights {
    w := make([]f64, l)
    for i in 0..<l {
        w[i] = 1
    }

    return new_clone(Weights{
        w,
        make([]int, l),
        make([]int, l)
    })
}
update_weights :: proc(w :^Weights, conf : Alns_conf) {
    for i in 0..<len(w.W) {
        if w.N[i] == 0 {continue}

        ol := (1 - conf.react_fact) * w.W[i]
        nw := conf.react_fact * (f64(w.S[i]) / f64(w.N[i]))

        w.W[i] = ol + nw
    }
}
delete_weights :: proc(w : ^Weights) {
    delete(w.W)
    delete(w.S)
    delete(w.N)
    free(w)
}

Warm_Up :: 200 

warm_up_temp :: proc(g : ^Garden, conf : Alns_conf) -> SA_conf {
    temp := copy_garden(g)
    defer delete_garden(temp)

    path_change : f64 = 0
    bot_change : f64 = 0

    c1 := 0
    c2 := 0

    for i in 0..<Warm_Up {
        r := rand.choice(conf.rem)
        a := rand.choice(conf.add)
        alns_update(temp, r, a)

        path := temp.tot_size - g.tot_size
        if path > 0 {
            path_change += path
            c1 += 1
        }
        bot := f64(len(temp.routes) - len(g.routes))
        if bot > 0 {
            bot_change += bot
            c2 += 1
        }
        
        rewrite_garden(temp, g)
    }

    // safety values for rare case.
    if c1 > 0 {path_change /= f64(c1)} else {path_change = 1}
    if c2 > 0 {bot_change /= f64(c2)} else {bot_change = 1}


    path_start := -path_change / math.ln(f64(0.5)) * conf.temp_mul
    bot_start := -bot_change / math.ln(f64(0.01)) * conf.temp_mul

    path_end := -path_change / math.ln(f64(0.00_01))
    bot_end := -bot_change / math.ln(f64(0.00_001))

    path_num := math.ln(path_end) - math.ln(path_start)
    bot_num := math.ln(bot_end) - math.ln(bot_start)
    path_decay := math.exp(path_num / f64(conf.its))
    bot_decay := math.exp(bot_num / f64(conf.its))

    return SA_conf{
        {path_start, bot_start}, 
        {path_decay, bot_decay}
    }
}

alns :: proc(g : ^Garden, conf : Alns_conf) -> ^Garden {
    best_g := copy_garden(g)
    last_g := copy_garden(g)
    new_g := copy_garden(g)
    defer delete_garden(last_g)
    defer delete_garden(new_g)

    rem_W := init_weights(len(conf.rem))
    defer delete_weights(rem_W)
    add_W := init_weights(len(conf.add))
    defer delete_weights(add_W)
    
    SA := warm_up_temp(g, conf)
    
    counter : int = 1 // 1 to stop direct updating.
    no_imp : int = 0
    start_time := time.tick_now()

    c : [4]int
    highest : f64 = 0


    for true {
        // choose ops
        r := weighted_choose(rem_W.W)
        a := weighted_choose(add_W.W)

        alns_update(new_g, conf.rem[r], conf.add[a])
        
        new_cost := alns_cost(new_g)
        score := 0

        // score and update
        if new_cost < alns_cost(best_g) {
            
            rewrite_garden(best_g, new_g)
            rewrite_garden(last_g, new_g)
            score = 3

        } else if new_cost < alns_cost(last_g) {

            rewrite_garden(last_g, new_g)
            score = 2

        } else {
            
            path_change := new_g.tot_size - last_g.tot_size
            bot_change := f64(len(new_g.routes) - len(last_g.routes))

            path_succ := bot_change == 0 && rand.float64() < math.exp(-path_change / SA.temp[0])
            bot_succ := bot_change != 0 && rand.float64() < math.exp(-bot_change / SA.temp[1]) 

            if bot_succ || path_succ {
                rewrite_garden(last_g, new_g)
                score = 1
            } else {
                rewrite_garden(new_g, last_g)
            }
        }

        rem_W.S[r] += score
        rem_W.N[r] += 1

        add_W.S[a] += score
        add_W.N[a] += 1

        // regularly update weights
        if counter % conf.Wupdate == 0 {
            update_weights(rem_W, conf)
            update_weights(add_W, conf)
            
            slice.zero(rem_W.S)
            slice.zero(rem_W.N)

            slice.zero(add_W.S)
            slice.zero(add_W.N)

            if time.tick_since(start_time) > conf.time_limit {break}
        }

        // simulated annealing
        SA.temp *= SA.decay
        
        no_imp += 1
        counter += 1


        c[score] += 1
        if new_cost > highest {highest = new_cost}

        free_all(context.temp_allocator)

        if counter >= conf.its {break}
        if no_imp >= conf.patience {break}
        if score == 3 {no_imp = 0}
    }

    /*
    fmt.println("counts: ", c)
    fmt.println("highest_cost: ", highest)
    fmt.println("start_cost: ", alns_cost(g))

    fmt.println("its done: ", counter)
    */
    
    return best_g
}