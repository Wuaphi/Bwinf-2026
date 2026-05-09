package choreograph
import "core:os"
import "core:fmt"
import "core:unicode/utf8"
import "core:strings"
import "core:strconv"
import "core:math"
import "core:sort"
import "core:path/filepath"

Configuration :: [16]int
base_config : Configuration : {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15}

Action :: struct {
    name : string,
    length : int,
    reconfig : Configuration
}

leaderboard_rating :: struct {
    idx : int,
    different_figures : int,
    num_of_figures : int,
    total_distance : int
}


main :: proc() {

   curr_dir := os.get_current_directory()

    if filepath.base(curr_dir) != "Aufgabe2_choreograph" {
        fmt.println("ERROR: Arbeitsverzeichnis muss 'Aufgabe2_choreograph' sein.")
        os.exit(2)
    }

    eingaben_dir := filepath.join([]string{curr_dir, "eingaben"})
    ausgaben_dir := filepath.join([]string{curr_dir, "ausgaben"})
    
    eingaben_handle, error := os.open(eingaben_dir)
    eingaben_file_infos, error2 := os.read_dir(eingaben_handle, -1)
    os.close(eingaben_handle)

    for idx in 0..<len(eingaben_file_infos) {

        data, ok := os.read_entire_file(eingaben_file_infos[idx].fullpath)
        defer delete(data)

        if ok {

            content := string(data)
            output := brute_force_choreograph(content)

            path_name := strings.split(eingaben_file_infos[idx].name, ".")[0]
            output_file := strings.concatenate([]string{path_name, ".txt"})
            ausgaben_path := filepath.join([]string{ausgaben_dir, output_file})

            message := strings.concatenate([]string{path_name, " gab diesen Output:\n ", output})

            ok := os.write_entire_file(ausgaben_path, transmute([]byte)message)
            if !ok {
                fmt.println("ERROR: Fehler beim schreiben der datei: ", output_file)
            }

            fmt.println(message)

        } else {
            fmt.println("ERROR: Fehler beim lesen der Datei: ", eingaben_file_infos[idx].name)
        }
    }

}

brute_force_choreograph :: proc(input : string) -> string {

    parsed_input := strings.split_lines(input)
    total_length := strconv.atoi(parsed_input[0])

    actions := make([]Action, len(parsed_input) - 2)
    defer delete(actions)

    letter_map := make(map[rune]int)
    literal : []rune = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P'}
    for i in 0..<len(literal) {
        letter_map[literal[i]] = i
    }

    for i in 2..<len(parsed_input) {
        if len(parsed_input[i]) == 0 {
            actions = actions[0:(len(actions) - 1)]
            continue
        }

        act : Action
        splitted := strings.split(parsed_input[i], " ")
        act.name = splitted[0]
        act.length = strconv.atoi(splitted[1])
        runeArray := utf8.string_to_runes(splitted[2])
        for i2 in 0..<len(runeArray) {
            act.reconfig[i2] = letter_map[runeArray[i2]]
        }
        actions[i-2] = act
    }

    sort_after_length :: proc(a, b : Action) -> int {return  b.length - a.length}
    sort.quick_sort_proc(actions, sort_after_length)

    action_bounds := make([]int, len(actions))
    defer delete(action_bounds)
    for i in 0..<len(actions) {
        action_bounds[i] = int(math.floor(f32(total_length) / f32(actions[i].length)))
    }

    action_combinations := make([dynamic][]int)
    defer delete(action_combinations)
    action_exploration(actions, action_bounds, total_length, &action_combinations)

    tested_action_combinations := test_combinations(actions, action_combinations[:])
    defer delete(tested_action_combinations)

    if len(tested_action_combinations) == 0 {
        return "Keine Choreographien gefunden. \n"
    } else if len(tested_action_combinations) == 1 {
        return strings.concatenate([]string{"Nur eine Choreographie wurde gefunden: ", get_action_sequence(actions, tested_action_combinations[0])})
    } else {
        return get_sequence_leaderboard(actions, tested_action_combinations)
    }
}

get_sequence_leaderboard :: proc(actions : []Action, ta_comb : [dynamic][]int) -> string {
    ratings := make([]leaderboard_rating, len(ta_comb))
    defer delete(ratings)

    action_distances := find_actions_total_distance(actions)

    for i in 0..<len(ta_comb) {
        ratings[i].idx = i
        ratings[i].num_of_figures = len(ta_comb[i])
        
        actions_existing := make([]bool, len(actions))
        for act in ta_comb[i] {
            actions_existing[act] = true
        }
        unique_actions : int
        for exists in actions_existing {
            if exists {unique_actions += 1}
        }
        ratings[i].different_figures = unique_actions
        
        total_distance : int
        for act in ta_comb[i] {
            total_distance += action_distances[act]
        }
        ratings[i].total_distance = total_distance
    }


    unique_comparison :: proc(a, b : leaderboard_rating) -> int {return a.different_figures - b.different_figures}
    num_comparison :: proc(a, b : leaderboard_rating) -> int {return a.num_of_figures - b.num_of_figures}
    distance_comparison :: proc(a, b : leaderboard_rating) -> int {return a.total_distance - b.total_distance}

    result := make([dynamic]string)

    sort.quick_sort_proc(ratings, unique_comparison)

    append(&result, "Die Choreographie mit möglichst vielen unterschiedlichen Figuren lautet: ")
    append(&result, get_action_sequence(actions, ta_comb[ratings[len(ratings) - 1].idx]))
    append(&result, ". Und hat ")
    append(&result, fmt.tprint(ratings[len(ratings) - 1].different_figures))
    append(&result, " verschiedene Figuren. Es gibt außerdem ")

    topval := ratings[len(ratings) - 1].different_figures
    counter := -1

    for i in ratings {
        if i.different_figures == topval {
            counter += 1
        }
    }

    append(&result, fmt.tprint(counter))
    append(&result, " Choreographien, die genauso viele unterschieldiche Figuren haben. \n ")

    sort.quick_sort_proc(ratings, num_comparison)

    append(&result, "Die Choreographie mit den meisten Figuren lautet: ")
    append(&result, get_action_sequence(actions, ta_comb[ratings[len(ratings) - 1].idx]))
    append(&result, ". Und hat ")
    append(&result, fmt.tprint(ratings[len(ratings) - 1].num_of_figures))
    append(&result, " Figuren. Es gibt außerdem ")

    topval = ratings[len(ratings) - 1].num_of_figures
    counter = -1

    for i in ratings {
        if i.num_of_figures == topval {
            counter += 1
        }
    }
    append(&result, fmt.tprint(counter))
    append(&result, " Choreographien, die genauso viele Figuren haben. \n ")

    append(&result, "Die Choreographie mit den wenigesten Figuren lautet: ")
    append(&result, get_action_sequence(actions, ta_comb[ratings[0].idx]))
    append(&result, ". Und hat ")
    append(&result, fmt.tprint(ratings[0].num_of_figures))
    append(&result, " Figuren. Es gibt außerdem ")

    topval = ratings[0].num_of_figures
    counter = -1

    for i in ratings {
        if i.num_of_figures == topval {
            counter += 1
        }
    }
    append(&result, fmt.tprint(counter))
    append(&result, " Choreographien, die genauso wenige Figuren haben. \n ")

    sort.quick_sort_proc(ratings, distance_comparison)

    append(&result, "Die Choreographie mit der größt möglich zurückgelegten Strecke lautet: ")
    append(&result, get_action_sequence(actions, ta_comb[ratings[len(ratings) - 1].idx]))
    append(&result, ". Und es wird eine Distanz von ")
    append(&result, fmt.tprint(ratings[len(ratings) - 1].total_distance))
    append(&result, " zurückgelegt. Es gibt außerdem ")

    topval = ratings[len(ratings) - 1].total_distance
    counter = -1

    for i in ratings {
        if i.total_distance == topval {
            counter += 1
        }
    }
    append(&result, fmt.tprint(counter))
    append(&result, " Choreographien, die auch die gleiche zurückgelegte Strecke haben. \n ")

    append(&result, "Die Choreographie mit der kleinst möglich zurückgelegten Strecke lautet: ")
    append(&result, get_action_sequence(actions, ta_comb[ratings[0].idx]))
    append(&result, ". Und es wird eine Distanz von ")
    append(&result, fmt.tprint(ratings[0].total_distance))
    append(&result, " zurückgelegt. Es gibt außerdem ")

    topval = ratings[0].total_distance
    counter = -1

    for i in ratings {
        if i.total_distance == topval {
            counter += 1
        }
    }
    append(&result, fmt.tprint(counter))
    append(&result, " Choreographien, die auch die gleiche zurückgelegte Strecke haben. \n ")

    return strings.concatenate(result[:])
}

get_action_sequence :: proc(actions : []Action, action_indices: []int) -> string {
    temp := make([dynamic]string)
    defer delete(temp)

    for i in 0..<len(action_indices) {
        append(&temp, actions[action_indices[i]].name)
        if i == (len(action_indices) - 1 ) {continue}
        append(&temp, ", ")
    }
    return strings.concatenate(temp[:])
}

find_actions_total_distance :: proc(actions : []Action) -> []int {
    distances := make([]int, len(actions))
    for i in 0..<len(actions) {
        for i2 in 0..<16 {
            distances[i] += math.abs(i2 - actions[i].reconfig[i2])
        }
    }
    return distances
}

test_combinations :: proc(actions : []Action, action_combinations : [][]int) -> [dynamic][]int {
    startconfig : Configuration
    for i in 0..<16 {
        startconfig[i] = i
    }
    all_findings := make([dynamic][]int)
    for combi in action_combinations {
        findings := recursive_combi_finding(actions, combi, {}, startconfig)
        for find in findings {
            append(&all_findings, find)
        }
    }
    return all_findings
}

recursive_combi_finding :: proc(actions : []Action, actions_left : []int , actions_done : []int, config : Configuration) -> [dynamic][]int {
    empty := true
    for left in actions_left {
        if left > 0 {empty = false}
    }

    if empty {
        if config != base_config {
            delete(actions_done)
            delete(actions_left)
            return make([dynamic][]int)
        }

        delete(actions_left)
        temp := make([dynamic][]int)
        append(&temp, actions_done)
        return temp

    } else {

        findings := make([dynamic][]int)

        for i in 0..<len(actions) {
            if actions_left[i] == 0 {continue}

            temp_actions_left := make([]int, len(actions_left))
            copy(temp_actions_left, actions_left)
            temp_actions_left[i] -= 1

            temp_actions_done := make([]int, len(actions_done) + 1)
            copy(temp_actions_done, actions_done)
            temp_actions_done[len(actions_done)] = i

            temp_config := reconfigure(config, actions[i].reconfig)

            finding := recursive_combi_finding(actions, temp_actions_left, temp_actions_done, temp_config)
            for find in finding {
                append(&findings, find)
            }
        }

        delete(actions_left)
        delete(actions_done)
        return findings
    }
}

reconfigure :: proc(base, reconfig : Configuration) -> Configuration {
    temp  : Configuration
    for i in 0..<len(base) {
        temp[i] = base[reconfig[i]]
    }
    return temp
}

action_exploration :: proc(actions : []Action, action_bounds : []int, total_length : int, combis : ^[dynamic][]int) {

    action_testable_combis := make([dynamic][]int)
    action_testable_combis_lengths := make([dynamic]int)

    for i in 0..=action_bounds[0] {
        temp_holder := make([]int, 1)
        temp_holder[0] = i

        append(&action_testable_combis, temp_holder)
        append(&action_testable_combis_lengths, i * actions[0].length)
    }

    for len(action_testable_combis) > 0 {

        action_length := action_testable_combis_lengths[0]


        if action_length > total_length {
            delete(action_testable_combis[0])
            unordered_remove(&action_testable_combis, 0)
            unordered_remove(&action_testable_combis_lengths, 0)
            continue
        }

        if len(action_testable_combis[0]) == len(actions) {

            if action_length == total_length {
                append(combis, action_testable_combis[0])
            } else {
                delete(action_testable_combis[0])
            }

        } else {

            new_action_index := len(action_testable_combis[0])

            for i in 0..=action_bounds[new_action_index] {
                temp_actions := make([]int, len(action_testable_combis[0]) + 1)
                copy(temp_actions, action_testable_combis[0])

                temp_actions[new_action_index] = i
                append(&action_testable_combis, temp_actions)

                new_action_length := actions[new_action_index].length * i
                append(&action_testable_combis_lengths, action_length + new_action_length)
            }

            delete(action_testable_combis[0])
        }
        
        unordered_remove(&action_testable_combis, 0)
        unordered_remove(&action_testable_combis_lengths, 0)
    }
    delete(action_testable_combis)
}
