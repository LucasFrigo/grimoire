package main

import "core:strings"
import "core:path/filepath"
import "core:unicode/utf8"
import "core:slice"
import "core:fmt"
import win32 "core:sys/windows"
import rl "vendor:raylib"



Item :: struct {
    name: string,
    path: string,
    score: int,
}

InvertedIndex :: map[string][dynamic]Item

TrieNode :: struct {
    children: map[rune]^TrieNode,
    is_end: bool,
    items: [dynamic]Item,
}

FuzzyFinder :: struct {
    index: InvertedIndex,
    trie_root: ^TrieNode,
    all_items: [dynamic]Item
}


scan_directory :: proc(finder: ^FuzzyFinder, root: string) {
    handle: win32.HANDLE
    data: win32.WIN32_FIND_DATAW

    pattern := strings.concatenate({root, `\*`})
    defer delete(pattern)

    handle = win32.FindFirstFileW(win32.utf8_to_wstring(pattern), nil)
    if handle == win32.INVALID_HANDLE_VALUE do return

    defer win32.FindClose(handle)

    for {
        name, ok := win32.wstring_to_utf8(raw_data(&data.cFileName), 1)
        full_path := filepath.join({root, name})
        defer delete(full_path)

        if data.dwFileAttributes & win32.FILE_ATTRIBUTE_DIRECTORY != 0 {
            if name != "." && name != ".." {
                scan_directory(finder, full_path) // Recursively search in subdirectories
            }
        } else {
            item := Item{name = strings.clone(name), path = strings.clone(full_path)}
            append(&finder.all_items, item)
            add_to_index(finder, item)
        }

        if !win32.FindNextFileW(handle, &data) do break
    }
}

add_to_index :: proc(finder: ^FuzzyFinder, item: Item) {
    for word in strings.fields(strings.to_lower(item.name)) {
        if items, exists := finder.index[word]; exists {
            append(&items, item)
        } else {
            finder.index[word] = make([dynamic]Item)
            append(&finder.index[word], item)   
        }

        add_to_trie(finder.trie_root, word, item)
    }
}

add_to_trie :: proc(root: ^TrieNode, word: string, item: Item) {
    node := root
    for r in word {
        if child, exists := node.children[r]; exists {
            node = child
        } else {
            new_node := new(TrieNode)
            new_node.children = make(map[rune]^TrieNode)
            node.children[r] = new_node
            node = new_node
        }
    }
    node.is_end = true
    append(&node.items, item)
}


levenshtein :: proc(a, b: string) -> int {
    a_len := utf8.rune_count_in_string(a)
    b_len := utf8.rune_count_in_string(b)

    if a_len == 0 do return b_len
    if b_len == 0 do return a_len

    dp := make([dynamic][dynamic]int, a_len + 1)
    defer delete(dp)
    for i in 0..=a_len {
        dp[i] = make([dynamic]int, b_len + 1)
        dp[i][0] = i
    }
    for j in 0..=b_len {
        dp[0][j] = j
    }

    for i in 1..=a_len {
        for j in 1..=b_len {
            cost := a[i-1] == b[j-1] ? 0 : 1
            dp[i][j] = min(
                dp[i-1][j] + 1,      // Deletion
                min(
                    dp[i][j-1] + 1,  // Insertion
                    dp[i-1][j-1] + cost, // Substitution
                )
            )
        }
    }
    return dp[a_len][b_len]
}


rank_items :: proc(query: string, items: []Item) -> [dynamic]Item {
    ranked := make([dynamic]Item, 0, len(items))
    query_lower := strings.to_lower(query)

    for &item in items {
        name_lower := strings.to_lower(item.name)
        distance := levenshtein(query_lower, name_lower)
        item.score = max(0, 100 - distance * 10) 
        if item.score > 30 { // Threshold for "good enough" matches
            append(&ranked, item)
        }
    }

    slice.sort_by(ranked[:], proc(a, b: Item) -> bool { return a.score > b.score })
    return ranked
}



autocomplete :: proc(root: ^TrieNode, prefix: string) -> [dynamic]Item {
    node := root
    for r in prefix {
        if child, exists := node.children[r]; exists {
            node = child
        } else {
            return make([dynamic]Item) // No matches
        }
    }
    return slice.to_dynamic(node.items[:])
}

search :: proc(finder: ^FuzzyFinder, query: string) -> []Item {
    if len(query) == 0 do return finder.all_items[:]  // Now works

    keywords := strings.fields(strings.to_lower(query))
    candidates: [dynamic]Item  // Dynamic for intermediate steps
    defer delete(candidates)

    for word in keywords {
        if items, exists := finder.index[word]; exists {
            if len(candidates) == 0 {
                // Copy slice to dynamic array
                candidates = make([dynamic]Item, len(items))
                for item, i in items {
                    candidates[i] = item
                }
            } else {
                // ... intersection logic ...
            }
        }
    }
    return candidates[:]  // Convert to slice before returning
}

UI_State :: struct {
    input_text:     [256]u8,  // Buffer for text input
    cursor_pos:     int,
    scroll_offset:  int,
    selected_index: int,
    font:           rl.Font,
    results:        []Item,
}

init_ui :: proc() -> UI_State {
    return UI_State {
        //font = rl.LoadFontEx("assets/font.ttf", 20, nil, 0), // Replace with your font
    }
}

draw_ui :: proc(state: ^UI_State) {
    rl.ClearBackground(rl.BLACK)

    // Draw input box
    rl.DrawRectangle(10, 10, 780, 40, rl.DARKGRAY)
    rl.DrawTextEx(
        state.font,
        strings.unsafe_string_to_cstring(string(state.input_text[:state.cursor_pos])),
        {20, 20},
        20,
        0,
        rl.WHITE,
    )

    // Draw results list
    for item, i in state.results {
        color := i == state.selected_index ? rl.YELLOW : rl.WHITE
        rl.DrawTextEx(
            state.font,
            strings.unsafe_string_to_cstring(item.name),
            {20, 60 + f32(i * 30) - f32(state.scroll_offset)},
            20,
            0,
            color,
        )
    }
}

update_ui :: proc(state: ^UI_State, finder: ^FuzzyFinder) {
    // Handle text input
    key := rl.GetCharPressed()
    if key != 0 && state.cursor_pos < len(state.input_text) - 1 {
        state.input_text[state.cursor_pos] = u8(key)
        state.cursor_pos += 1
        state.input_text[state.cursor_pos] = 0 // Null-terminate
    }

    // Backspace handling
    if rl.IsKeyPressed(rl.KeyboardKey.BACKSPACE) && state.cursor_pos > 0 {
        state.cursor_pos -= 1
        state.input_text[state.cursor_pos] = 0
    }

    // Trigger search on input change
    query := strings.string_from_ptr(&state.input_text[0], state.cursor_pos)
    state.results = search(finder, query)
}


main :: proc() {
    rl.InitWindow(800, 600, "Grimoire Launcher")
    rl.SetTargetFPS(60)
    defer rl.CloseWindow() 

    finder: FuzzyFinder

    ui_state := init_ui()
    defer rl.UnloadFont(ui_state.font)

    // Initial scan (run in background?)
    //scan_directory(&finder, "C:/Users/lukeg/")

    for !rl.WindowShouldClose() && !rl.IsKeyPressed(rl.KeyboardKey.ESCAPE) {
        update_ui(&ui_state, &finder)
        rl.BeginDrawing()
        draw_ui(&ui_state)
        rl.EndDrawing()
    } 

}