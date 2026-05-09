package aufgabe2
import "core:math"
import "core:slice"
import "core:container/queue"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:strconv"
import "core:fmt"
import "core:time"


// Build 2d tree for faster access.
build_tree :: proc(f : []Pos) -> []Pos {

    ranges : queue.Queue([4]int)
    queue.init(&ranges)
    defer queue.destroy(&ranges)
    queue.push_back(&ranges, [4]int{0, len(f), 0, 0})

    result := make([]Pos, len(f))
    
    for queue.len(ranges) > 0 {
        
        r := queue.pop_front(&ranges)
        if r[0] == r[1] {continue}
        sf := f[r[0]:r[1]]

        if r[3] == 0 {
            slice.sort_by(sf, proc(i, j : Pos) -> bool {return i[0] < j[0]})
        } else {
            slice.sort_by(sf, proc(i, j : Pos) -> bool {return i[1] < j[1]})
        }

        size := r[1] - r[0]
        m := 0

        if size > 1 {
            // find largest power of 2 under size ("The perfect tree")
            perfect := 1
            for perfect << 1 <= size {
                perfect <<= 1
            }
            
            // find num of incormplete lowest layer
            remainder := size - (perfect - 1)
            m = (perfect / 2 - 1) + min(remainder, perfect / 2)
        }

        result[r[2]] = sf[m]

        nidx := r[2] * 2 + 1
        nidx2 := r[2] * 2 + 2

        if nidx < len(f) {
            queue.push_back(&ranges, [4]int{
                r[0],
                r[0] + m,
                nidx,
                1 - r[3]
            })
        }

        if nidx2 < len(f) {
            queue.push_back(&ranges, [4]int{
                r[0] + m + 1,
                r[1],
                nidx2,
                1 - r[3]
            })
        }
    }

    return result
}

in_bounds :: proc(a, center : Pos, r : f64, dim : int) -> (bool, bool) {
    allow_right := true
    if a[dim] > (center[dim] + r) {
        allow_right = false
    }
    allow_left := true
    if a[dim] < (center[dim] - r) {
        allow_left = false
    }
    return allow_right, allow_left
}

tree_circle_search :: proc(f : []Pos, center : Pos, r : f64, alloc := context.allocator) -> [dynamic]int {

    sqr_r := r * r

    result := make([dynamic]int, alloc)

    check : queue.Queue([2]int)
    queue.init(&check, allocator = alloc)
    defer queue.destroy(&check)

    queue.push_back(&check, [2]int{0, 0})

    for queue.len(check) > 0 {
        p := queue.pop_front(&check)
        i := p[0]

        if _dist(f[i], center) <= sqr_r {append(&result, i)}

        nidx := i * 2 + 1
        nidx2 := i * 2 + 2

        allow_right, allow_left := in_bounds(f[i], center, r, p[1])

        if nidx < len(f) && allow_left {
            queue.push_back(&check, [2]int{nidx, 1 - p[1]})
        }
        if nidx2 < len(f) && allow_right{
            queue.push_back(&check, [2]int{nidx2, 1 - p[1]})
        }
    }

    return result
}