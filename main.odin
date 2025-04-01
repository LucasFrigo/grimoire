package main
import rl "vendor:raylib"


screen_width :: 800
screen_height :: 600

/////////////////////////////
///////// STRUCTS //////////
////////////////////////////
Item :: struct {
    name: string,
    path: string,
    score: int,
}

UI_State :: struct {
    input_text:     [256]u8,
    cursor_pos:     int,
    scroll_offset:  int,
    selected_index: int,
    font:           rl.Font,
    results:        []Item,
}




/////////////////////////////
///////// UI //////////
////////////////////////////
init_ui :: proc() -> UI_State {
    return UI_State {
        //font = rl.LoadFontEx("assets/font.ttf", 20, nil, 0)
    }
}


update_ui :: proc(state: UI_State) {

}

draw_ui :: proc(state: UI_State) {
    rl.ClearBackground(rl.DARKGRAY)
    rl.DrawRectangle(screen_height / 2, screen_width / 2, 225, 50, rl.WHITE)

}


main :: proc() {
    rl.InitWindow(screen_width, screen_height, "Grimoire")
    rl.SetTargetFPS(60)
    defer rl.CloseWindow()
    
    ui_state := init_ui()
    draw_ui(ui_state)

    for !rl.WindowShouldClose() {
        update_ui(ui_state)
    }
}