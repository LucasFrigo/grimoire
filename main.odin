package main

import "core:strings"
import "core:path/filepath"
import "core:unicode/utf8"
import "core:slice"
import "core:fmt"
import win32 "core:sys/windows"



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



main :: proc() {
}


