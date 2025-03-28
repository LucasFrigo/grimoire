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

}



main :: proc() {
}


