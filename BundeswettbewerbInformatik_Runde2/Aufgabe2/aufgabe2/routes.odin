package aufgabe2
import "core:os"
import "core:fmt"

Linked_Pairs :: struct {
    pair : Pair,
    next : ^Linked_Pairs,
    prev : ^Linked_Pairs,

    route : ^Route,
    pool_idx : int
}

Route :: struct {
    head : ^Linked_Pairs,
    length : int,
    size : f64,

    idx : int
}

Pool :: struct { 
    pl : []Linked_Pairs,
    fr : [dynamic]int
}

pool_buff :: 2
init_pool :: proc(l : int) -> ^Pool {
    rl := l + pool_buff

    out := new(Pool)

    out.pl = make([]Linked_Pairs, rl)
    out.fr = make([dynamic]int, rl)
    
    for i in 0..<rl {
        out.fr[i] = i
        out.pl[i].pool_idx = i
    }

    return out
}

alloc_pair :: proc(pl : ^Pool) -> ^Linked_Pairs {

    if len(pl.fr) == 0 {
        fmt.println("ERROR: POOL out of Memory!")
        os.exit(1)
    }

    idx := pop(&pl.fr)
    p := &pl.pl[idx]

    p.next = nil
    p.prev = nil

    p.route = nil
    p.pair = {0, 0}

    return p
}
free_pair :: proc(pl : ^Pool, p : ^Linked_Pairs) {
    append(&pl.fr, p.pool_idx)
}

init_route :: proc(pl : ^Pool, x : int) -> ^Route {
    r := new(Route)
    
    p := alloc_pair(pl)
    p.pair = {x, x}

    p.next = p
    p.prev = p
    p.route = r

    r.head = p
    r.size = 0
    r.length = 1

    return r
}

// parameter is first of the two edges
delete_edges :: proc(pl : ^Pool, p : ^Linked_Pairs) -> ^Linked_Pairs {

    if p.next == p {
        p.route.head = nil
        free_pair(pl, p)
        return nil
    }

    // build new edge
    newp := alloc_pair(pl)
    newp.pair = Pair{
        p.pair[0],
        p.next.pair[1]
    }

    // update route
    p.route.head = newp
    newp.route = p.route

    // hook into route.
    // if only two edges left, make self reference.
    if p.next.next != p {

        newp.prev = p.prev
        newp.next = p.next.next 

        p.prev.next = newp
        p.next.next.prev = newp

    } else {

        newp.prev = newp
        newp.next = newp
    
    }

    // clean up old edges
    free_pair(pl, p.next)
    free_pair(pl, p)

    return newp
}

// returns pointer to first of two new ones
insert_edge :: proc(pl : ^Pool, p : ^Linked_Pairs, pos : int) -> ^Linked_Pairs {
    // Build new edges
    newp := alloc_pair(pl)
    newp.pair = Pair{
        p.pair[0],
        pos
    }

    newp2 := alloc_pair(pl)
    newp2.pair = Pair{
        pos,
        p.pair[1]
    }

    // Update route
    p.route.head = newp
    newp.route = p.route
    newp2.route = p.route

    // Hook into route
    // Safeguard for self-pointing loop
    if p != p.next {

        newp.next = newp2
        newp.prev = p.prev

        newp2.next = p.next
        newp2.prev = newp

        newp.prev.next = newp
        newp2.next.prev = newp2

    } else {

        newp.next = newp2
        newp.prev = newp2

        newp2.next = newp
        newp2.prev = newp

    }

    // clean up old edge
    free_pair(pl, p)
    return newp
}

delete_pool :: proc(pl : ^Pool) {
    delete(pl.pl)
    delete(pl.fr)
    free(pl)
}

delete_route :: proc(r : ^Route) {
    free(r)
}

delete_routes :: proc(pl : ^Pool, routes : [dynamic]^Route) {
    for i in 0..<len(routes) {
        delete_route(routes[i])
    }
    delete(routes)
    delete_pool(pl)
}

delete_garden :: proc(g :^Garden) {    
    if g == nil {return}

    delete_routes(g.rout_pl, g.routes)
    
    delete(g.tree)
    delete(g.edges)

    free(g)
}
