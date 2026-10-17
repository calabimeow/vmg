format PE64 GUI
entry start

include "win64ax.inc"

load_image:
    mov rsi, rcx

    skip_program_name:
        cmp byte [rsi], " "
        je found_space
        cmp byte [rsi], 9
        je found_space
        cmp byte [rsi], 10
        je found_space
        cmp byte [rsi], 13
        je found_space
        inc rsi
        jmp skip_program_name

    found_space:
        cmp byte [rsi], 0
        je load_image_done
        cmp byte [rsi], " "
        je advance
        cmp byte [rsi], 9
        je advance
        jmp parse_filename

    advance:
        inc rsi
        jmp found_space

    parse_filename:
        mov rdi, image_name
        cmp byte [rsi], '"'
        jne copy_loop
        inc rsi

    copy_loop:
        cmp byte [rsi], 0
        je load_image_done
        cmp byte [rsi], '"'
        je load_image_done
        mov al, byte [rsi]
        mov byte [rdi], al
        inc rsi
        inc rdi
        jmp copy_loop

    load_image_done:
        mov byte [rdi], 0
        inc rsi
        ret

main_loop:
    poll:
        mov rcx, event
        call [SDL_PollEvent]

        cmp dword [event], 256
        je quit

        cmp dword [event], 1025
        je on_mouse_down

        cmp dword [event], 1026
        je on_mouse_up

        cmp dword [event], 1024
        je on_mouse_motion

        cmp dword [event], 1027
        je on_mouse_wheel

        mov rcx, [renderer]
        mov rdx, 40
        mov r8, 40
        mov r9, 40
        call [SDL_SetRenderDrawColor]

        mov rcx, [renderer]
        call [SDL_RenderClear]

        movss xmm0, dword [image_rect + 8]
        mulss xmm0, dword [zoom]
        movss dword [dest_rect + 8], xmm0

        movss xmm0, dword [image_rect + 12]
        mulss xmm0, dword [zoom]
        movss dword [dest_rect + 12], xmm0

        movss xmm0, dword [image_rect + 0]
        movss dword [dest_rect + 0], xmm0
        movss xmm0, dword [image_rect + 4]
        movss dword [dest_rect + 4], xmm0

        mov rcx, [renderer]
        mov rdx, [image]
        mov r8, 0
        mov r9, dest_rect
        call [SDL_RenderTexture]

        mov rcx, [image_name_text_obj]
        mov rdx, 50
        mov r8, 50
        call [TTF_DrawRendererText]

        mov rcx, [renderer]
        call [SDL_RenderPresent]
        
        jmp poll

    on_mouse_down:
        mov byte [dragging], 1
        jmp poll

    on_mouse_up:
        mov byte [dragging], 0
        jmp poll

    on_mouse_motion:
        cmp byte [dragging], 0
        je poll

        movss xmm0, dword [event + 36]
        addss xmm0, dword [image_rect + 0]
        movss dword [image_rect + 0], xmm0

        movss xmm0, dword [event + 40]
        addss xmm0, dword [image_rect + 4]
        movss dword [image_rect + 4], xmm0

        jmp poll

    on_mouse_wheel:
        movss  xmm0, dword [event + 28]
        mulss  xmm0, dword [zoom_step]
        addss  xmm0, dword [zoom]

        maxss  xmm0, dword [zoom_min]
        minss  xmm0, dword [zoom_max]

        movss  xmm1, dword [zoom]
        movss  xmm2, xmm0
        divss  xmm2, xmm1

        movss  dword [zoom], xmm0

        movss  xmm3, dword [event + 36]
        movss  xmm4, xmm3
        subss  xmm4, dword [image_rect + 0]
        mulss  xmm4, xmm2
        subss  xmm3, xmm4
        movss  dword [image_rect + 0], xmm3

        movss  xmm3, dword [event + 40]
        movss  xmm4, xmm3
        subss  xmm4, dword [image_rect + 4]
        mulss  xmm4, xmm2
        subss  xmm3, xmm4
        movss  dword [image_rect + 4], xmm3

        jmp poll

    quit:
        ret

start:
    sub rsp, 56

    call [GetCommandLineA]
    mov rcx, rax
    call load_image

    mov rcx, 32
    call [SDL_Init]

    call [TTF_Init]

    mov rcx, window_name
    mov rdx, 800
    mov r8, 600
    mov r9, 4
    call [SDL_CreateWindow]
    mov [window], rax

    mov rcx, [window]
    mov rdx, render_mode
    call [SDL_CreateRenderer]
    mov [renderer], rax
    
    mov rcx, [renderer]
    mov rdx, image_name
    call [IMG_LoadTexture]
    mov [image], rax
    cmp rax, 0
    je error

    mov rcx, [renderer]
    call [TTF_CreateRendererTextEngine]
    mov [text_engine], rax 

    mov rcx, font_data
    mov rdx, font_size
    call [SDL_IOFromConstMem] 
    cmp rax, 0
    je error

    mov rcx, rax
    mov rdx, 1
    movss xmm2, dword [font_size]
    call [TTF_OpenFontIO]
    mov [font], rax
      
    mov rcx, [text_engine]
    mov rdx, [font]
    mov r8, image_name
    mov r9, 0
    call [TTF_CreateText]
    mov [image_name_text_obj], rax
    cmp rax, 0
    je error

    mov rcx, [image_name_text_obj]
    mov rdx, 255
    mov r8, 255
    mov r9, 255
    mov dword [rsp + 32], 255
    call [TTF_SetTextColor]
    cmp rax, 0
    je error

    sub rsp, 40
    call main_loop
    add rsp, 40

    call [SDL_DestroyWindow]
    call [SDL_Quit]

    call [ExitProcess]
    
    error:
        call [SDL_GetError]
        mov rcx, rax
        xor rdx, rdx
        mov r8, rax
        mov r9, 0
        mov rcx, 0
        call [MessageBoxA]
        call [ExitProcess]

section ".data" data readable writeable
    window_name db "vmg", 0
    render_mode db "opengl", 0
    window dq ?
    renderer dq ?
    font dq ?
    font_name db "W95FA.otf", 0
    font_size dd 24.0
    text_engine dq ?
    image_name_text_obj dq ?
    running db 1
    event rb 2048
    image_name rb 512
    image dq ?
    image_rect dd 150.0, 50.0, 500.0, 500.0
    dest_rect dd 0.0, 0.0, 0.0, 0.0
    zoom dd 1.0
    zoom_max dd 3.0
    zoom_min dd 0.5
    zoom_step dd 0.1
    dragging db 0

    font_data:
        file "W95FA.otf"
    font_data_end:
    font_data_size = font_data_end - font_data
    

section ".idata" import data readable writeable
    library sdl, "sdl3.dll", sdl_image, "sdl3_image.dll", sdl_ttf, "sdl3_ttf.dll", \
        kernel, "kernel32", user, "user32.dll"

    import sdl, \
        SDL_Init, "SDL_Init", \
        SDL_CreateWindow, "SDL_CreateWindow", \
        SDL_Delay, "SDL_Delay", \
        SDL_CreateRenderer, "SDL_CreateRenderer", \
        SDL_SetRenderDrawColor, "SDL_SetRenderDrawColor", \
        SDL_PollEvent, "SDL_PollEvent", \
        SDL_RenderPresent, "SDL_RenderPresent", \
        SDL_RenderTexture, "SDL_RenderTexture", \
        SDL_RenderClear, "SDL_RenderClear", \
        SDL_Quit, "SDL_Quit", \
        SDL_DestroyWindow, "SDL_DestroyWindow", \
        SDL_GetError, "SDL_GetError", \
        SDL_IOFromConstMem, "SDL_IOFromConstMem"

    import sdl_image, \
        IMG_LoadTexture, "IMG_LoadTexture"

    import sdl_ttf, \
        TTF_Init, "TTF_Init", \
        TTF_OpenFont, "TTF_OpenFont", \
        TTF_CreateRendererTextEngine, "TTF_CreateRendererTextEngine", \
        TTF_CreateText, "TTF_CreateText", \
        TTF_DrawRendererText, "TTF_DrawRendererText", \
        TTF_SetTextColor, "TTF_SetTextColor", \
        TTF_OpenFontIO, "TTF_OpenFontIO"

    import kernel, \
        GetCommandLineA, "GetCommandLineA", \
        ExitProcess, "ExitProcess"

    import user, \
        MessageBoxA, "MessageBoxA"
