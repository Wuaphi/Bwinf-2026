package aufgabe2

import rl "vendor:raylib"
import "core:time"

WIDTH :: 1000
HEIGHT :: 1000

_vis :: proc(f : []Pos, routes : [dynamic]^Route = nil) {

    cam :: rl.Camera2D{
        {WIDTH / 2, HEIGHT /2},
        {0, 0},
        0,
        1
    }

    min_x, max_x := f[0][0], f[0][0]
    min_y, max_y := f[0][1], f[0][1]

    for i in 1..<len(f) {
        if f[i][0] > max_x {max_x = f[i][0]}
        if f[i][1] > max_y {max_y = f[i][1]}

        if f[i][0] < min_x {min_x = f[i][0]}
        if f[i][1] < min_y {min_y = f[i][1]}
        
    }

    center_x := (min_x + max_x) / 2
    center_y := (min_y + max_y) / 2

    forest_width := max(max_x - min_x, 0.0001)
    forest_height := max(max_y - min_y, 0.0001)

    scale_x := (f64(WIDTH) * 0.9) / forest_width
    scale_y := (f64(HEIGHT) * 0.9) / forest_height
    scale := min(scale_x, scale_y)

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.WHITE)
        rl.BeginMode2D(cam)
        
        if routes != nil {
            for r in routes {
                curr := r.head
                for true {
                    p := curr.pair

                    rl.DrawLine(
                        i32((f[p[0]][0] - center_x) * scale),
                        i32((f[p[0]][1] - center_y) * scale),
                        i32((f[p[1]][0] - center_x) * scale),
                        i32((f[p[1]][1] - center_y) * scale),
                        rl.GREEN    
                    )

                    curr = curr.next
                    if curr == r.head {break}
                }
            }
        }
        
        for i in 0..<len(f) {
            rl.DrawCircle(
                i32((f[i][0] - center_x) * scale),
                i32((f[i][1] - center_y) * scale),
                3,
                rl.RED
            )
        }

        rl.EndMode2D()
        rl.EndDrawing()

        if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {break}
    }
}

vis_garden :: proc(g : ..^Garden) {
    rl.InitWindow(WIDTH, HEIGHT, "Forest")
    for i in g {
        _vis(i.tree, i.routes)
    }
    rl.CloseWindow()
}

vis_forest :: proc(g : ..[]Pos) {
    rl.InitWindow(WIDTH, HEIGHT, "Forest")
    for i in g {
        _vis(i)
    }
    rl.CloseWindow()
}