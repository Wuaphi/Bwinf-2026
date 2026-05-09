package aufgabe2

/*
Linked_Pairs :: struct {
    pair : Pair,
    next : ^Linked_Pairs,
    prev : ^Linked_Pairs
}
*/

switch_edges :: proc(a, b : ^Linked_Pairs) {
    if a.next == b || a.prev == b {
        return
    }

    e1 := a.pair
    e2 := b.pair

    a.pair = Pair{e1[0], e2[0]}
    b.pair = Pair{e1[1], e2[1]} 

    start_rev := a.next
    end_rev := b.prev

    curr := start_rev
    for curr != b {
        temp_next := curr.next

        curr.next = curr.prev
        curr.prev = temp_next

        curr.pair = Pair{curr.pair[1], curr.pair[0]}

        curr = temp_next
    }

    start_rev.next = b
    b.prev = start_rev

    end_rev.prev = a
    a.next = end_rev
}

two_opt_cost :: proc(graph : []$T, p1, p2 : Pair) -> f64 {

    cost : f64 = 0
    cost += dist(idx(graph, p1[0]), idx(graph, p1[1]))
    cost += dist(idx(graph, p2[0]), idx(graph, p2[1]))
    return cost
}

compare_two_opt :: proc(graph : []$T, edge1, edge2 : ^Linked_Pairs) -> f64 {
    if edge1 == edge2 {return 0}

    p1 := edge1.pair
    p2 := edge2.pair

    sp1 := Pair{p1[0], p2[0]}
    sp2 := Pair{p1[1], p2[1]}

    c1 := two_opt_cost(graph, sp1, sp2) 
    c2 := two_opt_cost(graph, p1, p2) 

    if c1 < c2 {
        switch_edges(edge1, edge2)
        return c2 - c1
    }
    return 0
}

two_opt :: proc(graph : []$T, edges : ^Linked_Pairs) -> f64 {

    amount_changed : f64 = 0

    tries: for true {
        curr1 := edges

        for true {
            curr2 := curr1.next.next
            
            for true {
                changed := compare_two_opt(graph, curr1, curr2)
                if changed > 0 {
                    amount_changed += changed
                    continue tries
                }
                
                curr2 = curr2.next
                if curr2 == curr1 {break}
            }

            curr1 = curr1.next
            if curr1 == edges {break}
        }

        break
    }

    return amount_changed 
}