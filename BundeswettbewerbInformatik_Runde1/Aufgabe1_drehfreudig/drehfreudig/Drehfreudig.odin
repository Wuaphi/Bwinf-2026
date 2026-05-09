package drehfreudig
import "core:fmt"
import "core:unicode/utf8"
import "core:os"
import "core:strings"
import "core:sort"
import "core:math"
import "core:path/filepath"
import rl "vendor:raylib"

node :: struct{
    parent : ^node,
    partition : f32,
    depth : int,
    children : [dynamic]^node,
    visualization : visualization_data
}

visualization_data :: struct {
    pos : [2]rl.Vector2,
    rectangle : [2]rl.Rectangle
}

post_calc_data :: struct {
    tree : ^node,
    name : string
}

main :: proc() {
    curr_dir := os.get_current_directory()

    if filepath.base(curr_dir) != "Aufgabe1_drehfreudig" {
        fmt.println("ERROR: Arbeitsverzeichnis muss 'Aufgabe1_drehfreudig' sein.")
        os.exit(2)
    }

    eingaben_dir := filepath.join([]string{curr_dir, "eingaben"})
    ausgaben_dir := filepath.join([]string{curr_dir, "ausgaben"})
    
    eingaben_handle, error := os.open(eingaben_dir)
    eingaben_file_infos, error2 := os.read_dir(eingaben_handle, -1)
    os.close(eingaben_handle)

    drehfreudige_trees := make([dynamic]post_calc_data)
    nicht_drehfreudige_trees := make([dynamic]post_calc_data)

    rl.SetTraceLogLevel(.NONE)
    rl.InitWindow(1000, 1000, "Drehfreudig")

    for idx in 0..<len(eingaben_file_infos) {
        data, ok := os.read_entire_file(eingaben_file_infos[idx].fullpath)
        defer delete(data)

        if ok {
            content := string(data)
            ausgaben_path := strings.split(eingaben_file_infos[idx].name, ".")[0]

            drehfreudig, root := is_drehfreudig(content, filepath.join([]string{ausgaben_dir, ausgaben_path}))
            if drehfreudig {
                append(&drehfreudige_trees, post_calc_data{root, eingaben_file_infos[idx].name})
            } else {
                append(&nicht_drehfreudige_trees, post_calc_data{root, eingaben_file_infos[idx].name})
            }

        } else {
            fmt.println("ERROR: Fehler beim lesen der Datei: ", eingaben_file_infos[idx].name)
        }
    }
    d_trees := drehfreudige_trees[:]
    nd_trees := nicht_drehfreudige_trees[:]

    sort.quick_sort_proc(d_trees, number_in_name_sorting)
    sort.quick_sort_proc(nd_trees, number_in_name_sorting)

    post_calc_interaction(d_trees, nd_trees)

}


number_in_name_sorting :: proc(a, b : post_calc_data) -> int {
    a_num := extract_number_from_string(a.name)
    b_num := extract_number_from_string(b.name)

    return a_num - b_num
}

extract_number_from_string :: proc(input : string) -> int {
    rune_array := utf8.string_to_runes(input)

    rune_ints : [10]rune = {'0','1','2','3','4','5','6','7','8','9'}

    temp_int_holder := make([dynamic]int)
    defer delete(temp_int_holder)

    for char in rune_array {
        for i in 0..=9 {
            if char == rune_ints[i] {
                append(&temp_int_holder, i)
            }
        }
    }
    
    if len(temp_int_holder) > 0 {
        output : int
        for i in 0..<len(temp_int_holder) {
            output += temp_int_holder[i] * int(math.pow10(f64(len(temp_int_holder) - i - 1)))
        }
        return output
    } else {
        return 0
    }
}

post_calc_interaction :: proc(drehfreudige_trees : []post_calc_data, nicht_drehfreudige_trees : []post_calc_data) {

    if !(len(drehfreudige_trees) == 0 || len(nicht_drehfreudige_trees) == 0) {
        drehfreudig_display : int = 0
        nicht_drehfreudig_display : int = 0
        drehfreudig_or_not : bool = true
        cstring_to_display : cstring = get_cstring_to_display(0, len(drehfreudige_trees), drehfreudige_trees[0].name)


        for !rl.WindowShouldClose() {



            if drehfreudig_or_not {
                if rl.IsKeyPressed(.LEFT) && drehfreudig_display > 0 {
                    drehfreudig_display -= 1
                    cstring_to_display = get_cstring_to_display(
                        drehfreudig_display, 
                        len(drehfreudige_trees), 
                        drehfreudige_trees[drehfreudig_display].name
                    )
                } else if rl.IsKeyPressed(.RIGHT) && drehfreudig_display < (len(drehfreudige_trees) - 1) {
                    drehfreudig_display += 1
                    cstring_to_display = get_cstring_to_display(
                        drehfreudig_display, 
                        len(drehfreudige_trees), 
                        drehfreudige_trees[drehfreudig_display].name
                    )
                } else if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.DOWN) {
                    drehfreudig_or_not = !drehfreudig_or_not
                    cstring_to_display = get_cstring_to_display(
                        nicht_drehfreudig_display, 
                        len(nicht_drehfreudige_trees), 
                        nicht_drehfreudige_trees[nicht_drehfreudig_display].name,
                        false
                    )
                }
            } else {
                if rl.IsKeyPressed(.LEFT) && nicht_drehfreudig_display > 0 {
                    nicht_drehfreudig_display -= 1
                    cstring_to_display = get_cstring_to_display(
                        nicht_drehfreudig_display, 
                        len(nicht_drehfreudige_trees), 
                        nicht_drehfreudige_trees[nicht_drehfreudig_display].name,
                        false
                    )
                } else if rl.IsKeyPressed(.RIGHT) && nicht_drehfreudig_display < (len(nicht_drehfreudige_trees) - 1) {
                    nicht_drehfreudig_display += 1
                    cstring_to_display = get_cstring_to_display(
                        nicht_drehfreudig_display, 
                        len(nicht_drehfreudige_trees), 
                        nicht_drehfreudige_trees[nicht_drehfreudig_display].name,
                        false
                    )
                } else if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.DOWN) {
                    drehfreudig_or_not = !drehfreudig_or_not
                    cstring_to_display = get_cstring_to_display(
                        drehfreudig_display, 
                        len(drehfreudige_trees), 
                        drehfreudige_trees[drehfreudig_display].name
                    )
                }
            }
            

            rl.BeginDrawing()
                rl.DrawRectangle(0, 0, 1000, 1000, rl.YELLOW)
                if drehfreudig_or_not {
                    visualize(drehfreudige_trees[drehfreudig_display].tree)
                } else {
                    visualize(nicht_drehfreudige_trees[nicht_drehfreudig_display].tree)
                }
                

                rl.DrawText(cstring_to_display, 10, 10, 20, rl.BLUE)
                if drehfreudig_or_not {
                    rl.DrawText("Nutze Pfeil nach links und rechts um den dargestellten 'drehfreudigen Baum' zu ändern.", 10, 30, 20, rl.BLUE)
                    rl.DrawText("Um 'nicht drehfreudige Bäume' zu sehen, Pfeil nach oben oder unten verwenden. ", 10, 50, 20, rl.BLUE)
                } else {
                    rl.DrawText("Nutze Pfeil nach links und rechts um den dargestellten 'nicht drehfreudigen Baum' zu ändern.", 10, 30, 20, rl.BLUE)
                    rl.DrawText("Um 'drehfreudige Bäume' zu sehen, Pfeil nach oben oder unten verwenden. ", 10, 50, 20, rl.BLUE)
                }
            rl.EndDrawing()
        }
        
        rl.CloseWindow()
    }

    for obj in drehfreudige_trees {
        delete_tree(obj.tree)
    }
    delete(drehfreudige_trees)

    for obj in nicht_drehfreudige_trees {
        delete_tree(obj.tree)
    }
    delete(nicht_drehfreudige_trees)
}

get_cstring_to_display :: proc(display : int, len_trees : int, name : string, drehfreudigkeit : bool = true) -> cstring{
    m : string
    if drehfreudigkeit {
        m  = "Drehfreudiger Baum "
    } else {
        m = "Nicht drehfreudiger Baum "
    }

    string_to_display := strings.concatenate([]string{
        m,
        fmt.tprintf("%d", display + 1),
        " von ",
        fmt.tprintf("%d", len_trees),
        ":   ",
        name
    })
    return strings.clone_to_cstring(string_to_display)
}

delete_tree :: proc(nod : ^node) {
    for child in nod.children {
        delete_tree(child)
    }
    delete(nod.children)
    free(nod)
}

is_drehfreudig :: proc(input : string, ausgaben_path : string) -> (bool, ^node) {
    runeArray := utf8.string_to_runes(input)

    root : ^node = new(node)
    root.depth = 0
    root.partition = 1
    root.children = make([dynamic]^node)
    current_node : ^node = root
    first := true

    for char in runeArray {

        if char == '(' {

            if first {
                first = false
                continue
            }

            temp := new(node)
            temp.children = make([dynamic]^node)
            append(&current_node.children, temp)
            temp.depth = current_node.depth + 1
            temp.parent = current_node
            current_node = temp

        } else if char == ')' {
            current_node = current_node.parent
        }
    }

    assign_partition(root,first=true)

    leaves := make([dynamic]^node)
    find_leaves(root, &leaves)

    drehfreudig := check_drehfreudigkeit(root, leaves[:])

    ausgaben_path_base := filepath.base(ausgaben_path)

    output_file := strings.concatenate([]string{ausgaben_path, ".txt"})

    if drehfreudig {

        message := strings.concatenate([]string{ausgaben_path_base, " ist drehfreudig."})
        ok := os.write_entire_file(output_file, transmute([]byte)message)
        if !ok {
            fmt.println("ERROR: Fehler beim schreiben der datei: ", ausgaben_path)
        }
        fmt.println(message)

        produce_picture(root, leaves[:], ausgaben_path)

        delete(leaves)
        return true, root
    } else {

        message := strings.concatenate([]string{ausgaben_path_base, " ist nicht drehfreudig."})
        ok := os.write_entire_file(output_file, transmute([]byte)message)
        if !ok {
            fmt.println("ERROR: Fehler beim schreiben der datei: ", ausgaben_path)
        }
        fmt.println(message)

        produce_picture(root, leaves[:], ausgaben_path)

        delete(leaves)
        return false, root
    }

}

check_drehfreudigkeit :: proc(nod : ^node, leaves : []^node) -> bool {
    for idx in 0..<(len(leaves) / 2) {
        if leaves[idx].partition != leaves[len(leaves) - 1 - idx].partition {return false}
        if leaves[idx].depth != leaves[len(leaves) - 1 - idx].depth {return false}
    }
    return true,
}

find_leaves :: proc(nod : ^node, leaves : ^[dynamic]^node) {
    if len(nod.children) == 0 {
        append(leaves, nod)
    } else {
        for child in nod.children {
            find_leaves(child, leaves)
        }
    }
}

assign_partition :: proc(nod : ^node, first : bool = false) {
    if !first {
        nod.partition = nod.parent.partition / f32(len(nod.parent.children))
    }

    for child in nod.children {
        assign_partition(child)
    }
}

produce_picture :: proc(nod : ^node, leaves : []^node, ausgaben_path : string) {
    
    maxdepth := 0
    for i in 0..<len(leaves) {
        if leaves[i].depth > maxdepth {maxdepth = leaves[i].depth}
    }

    layer_height := f32(500) / f32(maxdepth + 1)
    find_visualization(nod, maxdepth, layer_height)

    rl.BeginDrawing()
        rl.DrawRectangle(0, 0, 1000, 1000, rl.YELLOW)
        visualize(nod)
    rl.EndDrawing()

    ausgabe := strings.concatenate([]string{ausgaben_path, ".png"})
    ausgaben_base := filepath.base(ausgabe)

    rl.TakeScreenshot(strings.clone_to_cstring(ausgaben_base))
    os.rename(ausgaben_base, ausgabe)
}

find_visualization :: proc(nod : ^node, maxdepth : int, layer_height : f32) {
    ypos := layer_height * f32(nod.depth)
    xpos : f32

    if nod.depth != 0 {
        pos_in_parents : int
        for idx in 0..<len(nod.parent.children) {
            if nod.parent.children[idx] == nod {pos_in_parents = idx}
        }
        xpos =  nod.parent.visualization.rectangle[0].x + 1000 * (nod.partition * f32(pos_in_parents))

    } else {
        xpos = 0
    }

    depth_diff_mul : f32 = 1
    if len(nod.children) == 0 {
        depth_diff_mul = f32(maxdepth - nod.depth + 1)
    }
    
    firstpos := rl.Vector2{xpos + ((nod.partition / 2) * 1000), ypos + ((layer_height * depth_diff_mul) / f32(2))}
    secondpos := rl.Vector2{1000 - (xpos + ((nod.partition / 2) * 1000)), 1000 - (ypos + ((layer_height * depth_diff_mul) / f32(2)))}
    nod.visualization.pos = {firstpos, secondpos}

    firstrectangle := rl.Rectangle{xpos, ypos, 1000 * nod.partition , (layer_height * depth_diff_mul)}
    secondrectangle := rl.Rectangle{1000 - xpos, 1000 - ypos, -1000 * nod.partition, -(layer_height * depth_diff_mul)}
    nod.visualization.rectangle = {firstrectangle, secondrectangle}

    for child in nod.children {
        find_visualization(child, maxdepth, layer_height)
    }
}

visualize :: proc(nod : ^node) {
    for i in 0..<2 {
        temp := &nod.visualization.rectangle[i]
        rl.DrawLineV(rl.Vector2{temp.x, temp.y}, rl.Vector2{temp.x, temp.y + temp.height}, rl.BLACK)
        rl.DrawLineV(rl.Vector2{temp.x + temp.width, temp.y}, rl.Vector2{temp.x + temp.width, temp.y + temp.height}, rl.BLACK)
        rl.DrawLineV(rl.Vector2{temp.x, temp.y}, rl.Vector2{temp.x + temp.width, temp.y}, rl.BLACK)

        if !(len(nod.children) == 0) {
        rl.DrawLineV(rl.Vector2{temp.x, temp.y + temp.height}, rl.Vector2{temp.x + temp.width, temp.y + temp.height}, rl.BLACK)
        }

        for child in nod.children {
            rl.DrawLineEx(child.visualization.pos[i], nod.visualization.pos[i], 5, rl.GRAY)
            if i == 1 {visualize(child)}
        }

        rl.DrawCircleV(nod.visualization.pos[i], 15, rl.RED)
    }
}



