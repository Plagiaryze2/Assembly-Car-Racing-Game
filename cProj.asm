org 0x0100
jmp START

; ================================================================================
; Variables
; ================================================================================
CAR_POS             dw 3114
TREE                dw 4
TRUNK               dw 2
ROWS                dw 1
COLS                dw 6
BUFFER              times 4000 db 0x20,0x07
TEMP_BUFFER         times 80 dw 0
MSG_TITLE           db 'CAR RACING GAME',0
MSG_ENTER_GAME      db '  Press Any Key to Continue!',0
MSG_ROLLS           db 'Roll Numbers: 24L-3004, 24L-3029',0
MSG_NAMES           db 'Names: M.Anas & Abdul Ahad',0
MSG_SEMESTER        db 'Semester & Section: Fall 2024 BSE-3B',0
TITLE_LENGTH        equ 16

MSG_CONFIRM         db 'Are you sure you want to exit? (Y/N)',0
MSG_SCORE           db 'Score: ',0
MSG_FINAL_SCORE     db 'Final Score: ',0
MSG_COLLISION       db 'CRASH!',0

OPP_CAR_ACTIVE      db 1
OPP_CAR_CURRENT_POS dw 50
SCROLL_COUNTER      db 0
COLLISION_FLAG      db 0
SCORE               dw 0
RANDOM_SEED         dw 0

BONUS_ACTIVE        db 0
BONUS_CURRENT_POS   dw 0
BONUS_SCROLL_COUNTER db 0

LANE1_POS           dw 50
LANE2_POS           dw 74
LANE3_POS           dw 98

DIAMOND_CHAR        equ 04h
DIAMOND_ATTR        equ 8Eh
BONUS_OFFSET_INSIDE_LANE equ 4

OLD_INTERRUPT_ISR   dd 0
OLD_KEYBOARD_ISR    dd 0
STOP_FLAG           dw 0
STOP_GAME           dw 0
TICK_COUNTER        dw 0

; ================================================================================
; Car ASCII art variables (for intro screen)
; ================================================================================
CAR_ANIM_POS        dw 0
CAR1                db '       ______',0
CAR2                db '      /|_| |_\`.__',0
CAR3                db '     (   _   _ _  \',0
CAR4                db '     =`-(_)--(_)--',0x27,0

; ================================================================================
; Tick Timer Interrupt Service Routine (ISR 08h)
; ================================================================================
NEW_INTERRUPT_ISR:
	pusha

	inc word[cs:TICK_COUNTER]
	cmp word[cs:TICK_COUNTER],85
	jae RESET_COUNTER
	jmp EXIT_ISR

RESET_COUNTER:
	mov word[cs:TICK_COUNTER],0
	call MOVE_CAR
	jmp EXIT_ISR
EXIT_ISR:
	mov al,0x20
	out 0x20,al
	popa
	iret

; ================================================================================
; Keyboard Interrupt Service Routine (ISR 09h)
; ================================================================================
NEW_KEYBOARD_ISR:
	pusha

	in al,0x60
	cmp al,0x4D
	je MOVE_RIGHT
	cmp al,0x4B
	je MOVE_LEFT
	cmp al,01
	je ESC_PRESSED
	jmp NO_KEY_MOVE

MOVE_LEFT:
	mov ax, [CAR_POS]
	sub ax, 6
	cmp ax, 3088
	jb NO_KEY_MOVE
	mov [CAR_POS], ax
	jmp NO_KEY_MOVE

MOVE_RIGHT:
	mov ax, [CAR_POS]
	add ax, 6
	cmp ax, 3142
	ja NO_KEY_MOVE
	mov [CAR_POS], ax
	jmp NO_KEY_MOVE

ESC_PRESSED:
	mov word[STOP_FLAG],1
	call ESC_CONFIRMATION

NO_KEY_MOVE:
	mov al,0x20
	out 0x20,al

	popa
	iret

; ================================================================================
; ESC Confirmation
; ================================================================================
ESC_CONFIRMATION:
	push ax
	push si
	push di
	push es

	mov ax, 0xb800
	mov es, ax
	mov di, 12*160+23*2
	mov si, MSG_CONFIRM
PRINT_CONFIRM:                         ;print the (Y and N message.) 
	lodsb
	cmp al, 0
	je WAIT_CONFIRM
	mov ah, 0x0C
	stosw
	jmp PRINT_CONFIRM

WAIT_CONFIRM:                          ;(printed message) -> waiting for key input.
	in al, 0x60

	cmp al, 0x15
	je DO_EXIT
	cmp al, 0x31
	je RESUME_GAME
	jmp WAIT_CONFIRM

DO_EXIT:                               ;(Y pressed)
	mov word[STOP_GAME],1
	jmp CONFIRMATION_RETURN

RESUME_GAME:                           ;(N pressed).
	mov word[STOP_FLAG],0
	mov ax, 0x0720
	mov cx, 80*2
	mov di, 12*160+25*2
	cld
	rep stosw
CONFIRMATION_RETURN:
	pop es
	pop di
	pop si
	pop ax
	ret

; ================================================================================
; Random Number Generator using LCG
; ================================================================================
INIT_RANDOM_SEED:
	push ax
	push cx
	push dx

	mov ah, 00h
	int 1Ah
	mov [RANDOM_SEED], dx   ;calls the timer interupt (gives no.of clock ticks since midnight). {diff each time}

	pop dx
	pop cx
	pop ax
	ret

GET_RANDOM_LANE:
	push ax
	push bx
	push cx

	mov ax, [RANDOM_SEED]
	mov bx, 25173          ;formula used { seed=(seed×25173+13849)mod65536 }
	mul bx
	add ax, 13849
	adc dx, 0

	mov [RANDOM_SEED], ax

	xor dx, dx
	mov bx, 3              ;3 Lanes Hence Xor by 3 ( Lane choosen based on remainder ).
	div bx

	cmp dx, 0
	je LANE_0
	cmp dx, 1
	je LANE_1
	jmp LANE_2

LANE_0:
	mov dx, [LANE1_POS]
	jmp LANE_DONE
LANE_1:
	mov dx, [LANE2_POS]
	jmp LANE_DONE
LANE_2:
	mov dx, [LANE3_POS]

LANE_DONE:
	pop cx
	pop bx
	pop ax
	ret

; ================================================================================
; Collision Detection
; ================================================================================
CHECK_COLLISION:
	pusha

	cmp byte [OPP_CAR_ACTIVE], 0       ;no Car Present
	je NO_COLLISION

	mov ax, [OPP_CAR_CURRENT_POS]      ;Calculating Car Bounds
	xor dx, dx
	mov bx, 160
	div bx
	mov bx, ax
	shr dx, 1
	mov si, dx

	mov ax, [CAR_POS]                  ;Comparing Player Car Position to check if no collisions
	xor dx, dx
	mov cx, 160
	div cx
	mov cx, ax
	shr dx, 1
	mov di, dx

	mov ax, bx
	add ax, 5
	cmp ax, cx
	jle NO_COLLISION

	mov ax, cx
	add ax, 5
	cmp ax, bx
	jle NO_COLLISION

	mov ax, si
	add ax, 6
	cmp ax, di
	jle NO_COLLISION

	mov ax, di
	add ax, 6
	cmp ax, si
	jle NO_COLLISION

	mov byte [COLLISION_FLAG], 1       ;All No_Collisions Conditions fail so collisions occured (set flag = 1).
	popa
	ret

NO_COLLISION:
	mov byte [COLLISION_FLAG], 0      ;else set Flag = 0.
	popa
	ret

; ================================================================================
; Display Score
; ================================================================================
DISPLAY_SCORE:
	pusha

	mov ax, 0xb800
	mov es, ax

	mov di, 140
	mov si, MSG_SCORE
	mov ah, 0x0E

PRINT_SCORE_LABEL:                     ;permanent Score Label at Top Right of Screen.
	lodsb
	cmp al, 0
	je PRINT_SCORE_VALUE
	stosw
	jmp PRINT_SCORE_LABEL

PRINT_SCORE_VALUE:
	mov ax, [SCORE]
	call PRINT_DECIMAL

	popa
	ret

PRINT_DECIMAL:                        ;Converting Char -> Integers.
	push ax
	push bx
	push cx
	push dx

	mov bx, 10
	xor cx, cx

CONVERT_LOOP:
	xor dx, dx
	div bx
	push dx
	inc cx
	test ax, ax                        ;checking if Co-efficent is Zero (all digits checked).
	jnz CONVERT_LOOP

	mov ah, 0x0E

DISPLAY_DIGITS:                        ;pop from stack and display on Screen.
	pop dx
	add dl, '0'
	mov al, dl
	stosw
	loop DISPLAY_DIGITS

	pop dx
	pop cx
	pop bx
	pop ax
	ret

; ================================================================================
; Opponent Car Management
; ================================================================================
INIT_OPP_CAR:
	push ax
	push dx

	call GET_RANDOM_LANE
	mov [OPP_CAR_CURRENT_POS], dx
	mov byte [OPP_CAR_ACTIVE], 1        ;EnemyCar = Active. (will appear).

	pop dx
	pop ax
	ret

CHECK_SPAWN_OPP_CAR:
	push ax

	inc byte [SCROLL_COUNTER]

	cmp byte [SCROLL_COUNTER], 8        ;Car Appears on number of Scrolls.
	jl CHECK_SPAWN_DONE

	mov byte [SCROLL_COUNTER], 0

	cmp byte [OPP_CAR_ACTIVE], 0
	jne CHECK_SPAWN_DONE

	call INIT_OPP_CAR

CHECK_SPAWN_DONE:
	pop ax
	ret

; ================================================================================
; Bonus object (spawn, draw, pickup)
; ================================================================================
INIT_BONUS:
	push ax
	push dx
	call GET_RANDOM_LANE
	add dx, BONUS_OFFSET_INSIDE_LANE
	mov [BONUS_CURRENT_POS], dx
	mov byte [BONUS_ACTIVE], 1
	pop dx
	pop ax
	ret

CHECK_SPAWN_BONUS:
	push ax
	inc byte [BONUS_SCROLL_COUNTER]      ;Appears on Number of Scrolls of Screen.
	cmp byte [BONUS_SCROLL_COUNTER], 6
	jl BONUS_SPAWN_DONE

	mov byte [BONUS_SCROLL_COUNTER], 0

	cmp byte [BONUS_ACTIVE], 0
	jne BONUS_SPAWN_DONE

	call INIT_BONUS
BONUS_SPAWN_DONE:
	pop ax
	ret

DRAW_BONUS:
	push es
	push ax
	push di

	cmp byte [BONUS_ACTIVE], 0
	je BONUS_DRAW_DONE

	add word [BONUS_CURRENT_POS], 160

	mov ax, [BONUS_CURRENT_POS]
	cmp ax, 4000-2
	jbe DRAW_BONUS_CHAR
	mov byte [BONUS_ACTIVE], 0
	jmp BONUS_DRAW_DONE

DRAW_BONUS_CHAR:
	mov ax, 0xb800
	mov es, ax
	mov di, [BONUS_CURRENT_POS]
	mov al, DIAMOND_CHAR
	mov ah, DIAMOND_ATTR
	stosw

BONUS_DRAW_DONE:
	pop di
	pop ax
	pop es
	ret

CHECK_BONUS_PICKUP:                 ;checks if player car collision with object.
	pusha

	cmp byte [BONUS_ACTIVE], 0
	je NO_PICKUP

	mov ax, [BONUS_CURRENT_POS]
	xor dx, dx
	mov bx, 160
	div bx
	shr dx, 1
	mov si, dx
	mov bx, ax

	mov ax, [CAR_POS]
	xor dx, dx
	mov cx, 160
	div cx
	mov cx, ax
	shr dx, 1
	mov di, dx

	cmp bx, cx
	jb NO_PICKUP
	mov ax, cx
	add ax, 4
	cmp bx, ax
	ja NO_PICKUP

	cmp si, di
	jb NO_PICKUP
	mov ax, di
	add ax, 5
	cmp si, ax
	ja NO_PICKUP

	add word [SCORE], 10
	mov byte [BONUS_ACTIVE], 0

NO_PICKUP:
	popa
	ret

; ================================================================================
; Draw Opponent Car and Scoring
; ================================================================================
DRAW_OPP_CAR:                              ;calling DrawCar Functions.
	pusha

	mov ax, 0xb800
	mov es, ax

	cmp byte [OPP_CAR_ACTIVE], 0
	je DRAW_OPP_CAR_DONE

	add word [OPP_CAR_CURRENT_POS], 160

	cmp word [OPP_CAR_CURRENT_POS], 3840
	jb DRAW_OPP_CAR_AT_CURRENT_POS

	inc word [SCORE]
	mov byte [OPP_CAR_ACTIVE], 0
	jmp DRAW_OPP_CAR_DONE

DRAW_OPP_CAR_AT_CURRENT_POS:
	mov di, [OPP_CAR_CURRENT_POS]

	call DRAW_OPP_CAR_BOTTOM
	call DRAW_OPP_CAR_LOWER_BODY
	call DRAW_OPP_CAR_WINDOWS
	call DRAW_OPP_CAR_UPPER_BODY
	call DRAW_OPP_CAR_ROOF

DRAW_OPP_CAR_DONE:
	popa
	ret

; ================================================================================
; Main Game Loop Logic (called by timer ISR)
; ================================================================================
MOVE_CAR:
	cmp word[STOP_FLAG],1                     ;called in ISR (stopFlag checks if ESC confirm screen present)
	je CALL_CONFIRM
	jmp MOVE_CONTINUE
CALL_CONFIRM:
	call ESC_CONFIRMATION
	ret
MOVE_CONTINUE:
	call RESTORE_SCREEN
	call SCROLL_DOWN
	call SAVE_SCREEN
	call RESTORE_SCREEN

	call DRAW_CAR

	call CHECK_SPAWN_OPP_CAR
	call CHECK_SPAWN_BONUS

	call DRAW_OPP_CAR
	call DRAW_BONUS
	call CHECK_BONUS_PICKUP

	call DISPLAY_SCORE
	call CHECK_COLLISION

	cmp byte [COLLISION_FLAG], 1               ;collision occured Game Ends.
	je GAME_OVER

	ret

GAME_OVER:
	mov word[STOP_GAME],1
	call DISPLAY_COLLISION_MESSAGE
	call LONG_DELAY
	call LONG_DELAY

DISPLAY_COLLISION_MESSAGE:                     ;Crashed Msg Appears.
	pusha

	mov ax, 0xb800
	mov es, ax

	mov di, 12*160 + 37*2
	mov si, MSG_COLLISION
	mov ah, 0x0C

CRASH_LOOP:
	lodsb
	cmp al, 0
	je CRASH_DONE
	stosw
	jmp CRASH_LOOP

CRASH_DONE:
	popa
	ret

; ================================================================================
; Delay routines
; ================================================================================
DELAY:
	push cx
	mov cx, 0xFFFF
L1:
	loop L1
	mov cx, 0xFFFF
L2:
	loop L2
	mov cx, 0xFFFF
L3:
	loop L3
	mov cx, 0xFFFF
L4:
	loop L4
	pop cx
	ret

LONG_DELAY:
	push cx
	mov cx, 0xFFFF
LD1:
	loop LD1
	mov cx, 0xFFFF
LD2:
	loop LD2
	mov cx, 0xFFFF
LD3:
	loop LD3
	mov cx, 0xFFFF
LD4:
	loop LD4
	mov cx, 0xFFFF
LD5:
	loop LD5
	mov cx, 0xFFFF
LD6:
	loop LD6
	mov cx, 0xFFFF
LD7:
	loop LD7
	mov cx, 0xFFFF
LD8:
	loop LD8
	pop cx
	ret

; ================================================================================
; Screen clearing functions
; ================================================================================
CLEAR_SCREEN:
	pusha
	mov ax, 0xb800
	mov es, ax
	xor di, di
	mov ax, 0x0720
	mov cx, 2000
	cld
	rep stosw
	popa
	ret

MINI_CLEAR_SCREEN:
	pusha
	mov ax, 0xb800
	mov es, ax
	mov di, 3000
	mov ax, 0x0720
	mov cx, 2000
	cld
	rep stosw
	popa
	ret

; ================================================================================
; Print String
; ================================================================================
PRINT_STRING:
PRINTING_LOOP:
	lodsb
	cmp al, 0
	je PRINT_DONE
	mov ah, 0Eh                   ;writes ax character by character + moves cursor.
	int 10h           
	jmp PRINTING_LOOP
PRINT_DONE:
	ret

; ================================================================================
; Print Car (for intro screen)
; ================================================================================
PRINT_CAR_ANIMATION:
	call MINI_CLEAR_SCREEN         ;Mini Car (Starting Screen).

	mov si, CAR1
	mov dh, 20
	mov dl, [CAR_ANIM_POS]
	call SET_CURSOR
	call PRINT_STRING

	mov si, CAR2
	mov dh, 21
	mov dl, [CAR_ANIM_POS]
	call SET_CURSOR
	call PRINT_STRING

	mov si, CAR3
	mov dh, 22
	mov dl, [CAR_ANIM_POS]
	call SET_CURSOR
	call PRINT_STRING

	mov si, CAR4
	mov dh, 23
	mov dl, [CAR_ANIM_POS]
	call SET_CURSOR
	call PRINT_STRING

	ret

; ================================================================================
; Intro Screen
; ================================================================================
INTRO_SCREEN:
	pusha

	call CLEAR_SCREEN                   ;print Messages (Names,Roll.No's etc).
	mov ax, cs
	mov ds, ax
	mov ax, 0B800h
	mov es, ax

	mov si, MSG_TITLE
	mov cx, 5
	call PRINT_CENTERED

	mov si, MSG_ENTER_GAME
	mov cx, 7
	call PRINT_LEFT_ALIGNED

	mov si, MSG_ROLLS
	mov cx, 10
	call PRINT_LEFT_ALIGNED

	mov si, MSG_NAMES
	mov cx, 12
	call PRINT_LEFT_ALIGNED

	mov si, MSG_SEMESTER
	mov cx, 14
	call PRINT_LEFT_ALIGNED

CAR_PRINT_LOOP:                              ;waits for Key to be Pressed to Continue.
	call PRINT_CAR_ANIMATION
	call DELAY
	call DELAY

	mov ah, 01h
	int 16h
	jz NO_KEY_PRESSED
EXIT_LOOP:
	popa
	ret

NO_KEY_PRESSED:                              ;continues if No Key Pressed.
	add word [CAR_ANIM_POS], 1
	mov ax, [CAR_ANIM_POS]
	cmp ax, 60
	jl CONTINUE_SCROLL
	jmp EXIT_LOOP

CONTINUE_SCROLL:
	jmp CAR_PRINT_LOOP

PRINT_CENTERED:                        
	mov dx, 80                                   ;total cols - wordLength / 2 (left and right spaces).
	sub dx, TITLE_LENGTH
	shr dx, 1
	mov ax, cx
	shl ax, 7
	mov bx, cx                                   ;multiplying by 160 (first 128 then 32) register shortage.
	shl bx, 5
	add ax, bx
	shl dx, 1
	add ax, dx
	mov di, ax

PRINT_CENTERED_LOOP:                             ;printing Characters.
	lodsb
	cmp al, 0
	je PRINT_CENTERED_DONE
	mov ah, 0x0F
	stosw
	jmp PRINT_CENTERED_LOOP
PRINT_CENTERED_DONE:
	ret

PRINT_LEFT_ALIGNED:
	mov dx, 25                      ;string starts 25 spaces from left.
	mov ax, cx
	shl ax, 7
	mov bx, cx
	shl bx, 5
	add ax, bx                     ;total 160 multiply.
	shl dx, 1
	add ax, dx
	mov di, ax

PRINT_LEFT_LOOP:
	lodsb
	cmp al, 0
	je PRINT_LEFT_DONE
	mov ah, 0x0F
	stosw
	jmp PRINT_LEFT_LOOP
PRINT_LEFT_DONE:
	ret

; ================================================================================
; Scenery Drawing
; ================================================================================
DRAW_SCAPE:                ;AL = D8 used for blocks (else less colorfull data problem.)
	pusha
	mov ax, 0xb800
	mov es, ax

	mov cx, 25
	xor dx, dx
DRAW_LEFT_ROWS:
	push cx
	mov di, dx
	mov ax, 0x2720
	mov cx, 22
DRAW_LEFT_COLS:
	mov word [es:di], ax
	add di, 2
	loop DRAW_LEFT_COLS
	pop cx
	add dx, 160
	loop DRAW_LEFT_ROWS

	mov cx, 25
	xor dx, dx
DRAW_YELLOW_COL_LEFT:
	mov di, dx
	add di, 22*2
	mov ax, 0x0EDB
	mov word [es:di], ax
	add dx, 160
	loop DRAW_YELLOW_COL_LEFT

	mov cx, 25
	xor dx, dx
DRAW_ROAD_ROWS:
	mov di, dx
	add di, 23*2
	mov ax, 0x7020
	mov bx, 10
DRAW_ROAD_COLS1:
	mov word [es:di], ax
	add di, 2
	dec bx
	jnz DRAW_ROAD_COLS1

	mov ax, 0x7020
	mov bx, dx
	shr bx, 8
	test bx, 2
	jnz SKIP_DASH1
	mov ax, 0x0FDB
SKIP_DASH1:
	mov word [es:di], ax
	add di, 2

	mov bx, 12
DRAW_ROAD_COLS2:
	mov word [es:di], 0x7020
	add di, 2
	dec bx
	jnz DRAW_ROAD_COLS2

	mov ax, 0x7020
	mov bx, dx
	shr bx, 8
	test bx, 2
	jnz SKIP_DASH2
	mov ax, 0x0FDB
SKIP_DASH2:
	mov word [es:di], ax
	add di, 2

	mov bx, 11
DRAW_ROAD_COLS3:
	mov word [es:di], 0x7020
	add di, 2
	dec bx
	jnz DRAW_ROAD_COLS3

	add dx, 160
	loop DRAW_ROAD_ROWS

	mov cx, 25
	xor dx, dx
DRAW_YELLOW_COL_RIGHT:
	mov di, dx
	add di, 58*2
	mov ax, 0x0EDB
	mov word [es:di], ax
	add dx, 160
	loop DRAW_YELLOW_COL_RIGHT

	mov cx, 25
	xor dx, dx
DRAW_RIGHT_ROWS:
	mov di, dx
	add di, 59*2
	mov ax, 0x2720
	mov bx, 21
DRAW_RIGHT_COLS:
	mov word [es:di], ax
	add di, 2
	dec bx
	jnz DRAW_RIGHT_COLS
	add dx, 160
	loop DRAW_RIGHT_ROWS

	popa
	ret

; ================================================================================
; Player Car Drawing (5 rows, 6 columns wide)
; ================================================================================
DRAW_CAR:
	pusha
	mov  ax, 0xb800
	mov  es, ax
	mov  di, [CAR_POS]

	call DRAW_CAR_ROOF
	call DRAW_CAR_UPPER_BODY
	call DRAW_CAR_WINDOWS
	call DRAW_CAR_LOWER_BODY
	call DRAW_CAR_BOTTOM

	popa
	ret

DRAW_CAR_ROOF:
	mov  al, 0DBh
	mov  ah, 0Eh
	stosw
	mov  cx, 4
	mov  al, 0DBh
	mov  ah, 0Ch
	rep  stosw
	mov  al, 0DBh
	mov  ah, 0Eh
	stosw
	add di, 148
	ret

DRAW_CAR_UPPER_BODY:
	mov cx, 6
	mov al, 0DBh
	mov ah, 0Ch
	rep stosw
	add di, 148
	ret

DRAW_CAR_WINDOWS:
	mov al, 0DBh
	mov ah, 08h
	stosw
	mov cx, 4
	mov al, 0DBh
	mov ah, 0Bh
	rep stosw
	mov al, 0DBh
	mov ah, 08h
	stosw
	add di, 148
	ret

DRAW_CAR_LOWER_BODY:
	mov al, 0DBh
	mov ah, 04h
	stosw
	mov cx, 4
	mov al, 0DBh
	mov ah, 0Ch
	rep stosw
	mov al, 0DBh
	mov ah, 04h
	stosw
	add di, 148
	ret

DRAW_CAR_BOTTOM:
	mov al, 0DBh
	mov ah, 70h
	stosw
	mov cx, 4
	mov al, 0DBh
	mov ah, 0Ch
	rep stosw
	mov al, 0DBh
	mov ah, 70h
	stosw
	ret

; ================================================================================
; Opponent Car Drawing (5 rows, 6 columns wide)
; ================================================================================
DRAW_OPP_CAR_BOTTOM:
	mov al, 0DBh
	mov ah, 70h
	stosw
	mov cx, 4
	mov al, 0DBh
	mov ah, 0Dh
	rep stosw
	mov al, 0DBh
	mov ah, 70h
	stosw
	add di, 148
	ret

DRAW_OPP_CAR_LOWER_BODY:
	mov al, 0DBh
	mov ah, 04h
	stosw
	mov cx, 4
	mov al, 0DBh
	mov ah, 0Dh
	rep stosw
	mov al, 0DBh
	mov ah, 04h
	stosw
	add di, 148
	ret

DRAW_OPP_CAR_WINDOWS:
	mov al, 0DBh
	mov ah, 08h
	stosw
	mov cx, 4
	mov al, 0DBh
	mov ah, 0Ah
	rep stosw
	mov al, 0DBh
	mov ah, 08h
	stosw
	add di, 148
	ret

DRAW_OPP_CAR_UPPER_BODY:
	mov cx, 6
	mov al, 0DBh
	mov ah, 0Dh
	rep stosw
	add di, 148
	ret

DRAW_OPP_CAR_ROOF:
	mov al, 0DBh
	mov ah, 0Eh
	stosw
	mov cx, 4
	mov al, 0DBh
	mov ah, 0Dh
	rep stosw
	mov al, 0DBh
	mov ah, 0Eh
	stosw
	ret

; ================================================================================
; Tree Drawing
; ================================================================================
DRAW_TREE:
	pusha
	mov ax, 0xb800
	mov es, ax

	mov cx, [TREE]
	mov bx, 0
TRIANGLE_ROW_LOOP:
	mov si, [COLS]
	sub si, bx
	mov bp, [COLS]
	add bp, bx
	mov dx, [ROWS]
	add dx, bx
	imul dx, 160
	mov ax, 0x0ADB
DRAW_ROW_LOOP:
	mov di, si
	shl di, 1
	add di, dx
	mov word [es:di], ax
	inc si
	cmp si, bp
	jg NEXT_ROW
	jmp DRAW_ROW_LOOP
NEXT_ROW:
	inc bx
	cmp bx, cx
	jne TRIANGLE_ROW_LOOP

	mov cx, [TRUNK]
	mov bx, 0
TRUNK_ROW_LOOP:
	mov dx, [ROWS]
	add dx, [TREE]
	add dx, bx
	imul dx, 160
	mov si, [COLS]
	mov bp, si
	inc bp
DRAW_TRUNK_ROW:
	mov ax, 0x06DB
	mov di, si
	shl di, 1
	add di, dx
	mov word [es:di], ax
	inc si
	cmp si, bp
	jl DRAW_TRUNK_ROW
NEXT_TRUNK_ROW:
	inc bx
	cmp bx, cx
	jne TRUNK_ROW_LOOP

	popa
	ret

DRAW_FOREST:
	call DRAW_TREE
	mov ax, 5
	mov [ROWS], ax
	mov ax, 73
	mov [COLS], ax
	call DRAW_TREE
	mov ax, 16
	mov [ROWS], ax
	mov ax, 65
	mov [COLS], ax
	call DRAW_TREE
	mov ax, 14
	mov [ROWS], ax
	mov ax, 15
	mov [COLS], ax
	call DRAW_TREE
	mov ax, 3
	mov [TREE], ax
	mov ax, 1
	mov [TRUNK], ax
	mov ax, 3
	mov [ROWS], ax
	mov ax, 65
	mov [COLS], ax
	call DRAW_TREE
	mov ax, 1
	mov [ROWS], ax
	mov ax, 70
	mov [COLS], ax
	call DRAW_TREE
	mov ax, 7
	mov [ROWS], ax
	mov ax, 62
	mov [COLS], ax
	call DRAW_TREE
	mov ax, 20
	mov [ROWS], ax
	mov ax, 76
	mov [COLS], ax
	call DRAW_TREE
	mov ax, 10
	mov [ROWS], ax
	mov ax, 8
	mov [COLS], ax
	call DRAW_TREE
	ret

; ================================================================================
; Screen Scrolling and Buffer Management
; ================================================================================
SCROLL_DOWN:                  ;Saves last row scrolls Down and restores last row to top.
	pusha
	mov ax, 0B800h
	mov ds, ax
	mov es, ax

	mov si, 24*160
	mov di, TEMP_BUFFER
	mov cx, 80
SAVE_BOTTOM:
	mov ax, word [ds:si]
	mov word [es:di], ax
	add si, 2
	add di, 2
	loop SAVE_BOTTOM

	std
	mov si, (24*160)-2
	mov di, (25*160)-2
	mov cx, 24*80
	rep movsw
	cld

	mov si, TEMP_BUFFER
	mov di, 0
	mov cx, 80
RESTORE_BOTTOM:
	mov ax, word [ds:si]
	mov word [es:di], ax
	add si, 2
	add di, 2
	loop RESTORE_BOTTOM
	popa
	ret

SAVE_SCREEN:
	pusha
	mov cx, 4000
	mov ax, 0xb800
	mov ds, ax
	push cs
	pop es
	mov si, 0
	mov di, BUFFER
	cld
	rep movsb
	popa
	ret

RESTORE_SCREEN:
	pusha
	mov cx, 4000
	push cs
	pop ds
	mov ax, 0xb800
	mov es, ax
	mov si, BUFFER
	mov di, 0
	cld
	rep movsb
	popa
	ret

; ================================================================================
; Cursor and Print Utilities
; ================================================================================
SET_CURSOR:
	mov ah, 02h         ;bh = pageNo , dh = rows. dl = cols.
	mov bh, 0
	int 10h
	ret

PRINT_AT:
	push ax
	push bx
	push cx
	mov ah, 09h
	mov bh, 0
	mov bl, 14
	mov cx, 1
	int 10h
	mov ah, 03h
	mov bh, 0
	int 10h
	inc dl
	mov ah, 02h
	int 10h
	pop cx
	pop bx
	pop ax
	ret

; ================================================================================
; "GAME OVER" Letter Drawing Functions
; ================================================================================
PRINT_G:
	mov dh, 5
	mov dl, 7
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT

	mov dh, 6
	mov dl, 6
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT

	mov dh, 7
	mov dl, 6
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	call PRINT_AT
	mov al, '*'
	call PRINT_AT
	call PRINT_AT

	mov dh, 8
	mov dl, 6
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	mov al, '*'
	call PRINT_AT

	mov dh, 9
	mov dl, 7
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	ret

PRINT_A:
	mov dh, 5
	mov dl, 16
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT

	mov dh, 6
	mov dl, 15
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	mov al, '*'
	call PRINT_AT

	mov dh, 7
	mov dl, 14
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT

	mov dh, 8
	mov dl, 14
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	mov al, '*'
	call PRINT_AT

	mov dh, 9
	mov dl, 14
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	mov al, '*'
	call PRINT_AT
	ret

PRINT_M:
	mov dh, 5
	mov dl, 21
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	mov al, '*'
	call PRINT_AT

	mov dh, 6
	mov dl, 21
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	mov al, '*'
	call PRINT_AT
	call PRINT_AT

	mov dh, 7
	mov dl, 21
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	mov al, '*'
	call PRINT_AT

	mov dh, 8
	mov dl, 21
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	mov al, '*'
	call PRINT_AT

	mov dh, 9
	mov dl, 21
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	mov al, '*'
	call PRINT_AT
	ret

PRINT_E:
	mov dh, 5
	mov dl, 28
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT

	mov dh, 6
	mov dl, 28
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT

	mov dh, 7
	mov dl, 28
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT

	mov dh, 8
	mov dl, 28
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT

	mov dh, 9
	mov dl, 28
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	ret

PRINT_O:
	mov dh, 5
	mov dl, 40
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT

	mov dh, 6
	mov dl, 39
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	mov al, '*'
	call PRINT_AT

	mov dh, 7
	mov dl, 39
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	mov al, '*'
	call PRINT_AT

	mov dh, 8
	mov dl, 39
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	mov al, '*'
	call PRINT_AT

	mov dh, 9
	mov dl, 40
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	ret

PRINT_V:
	mov dh, 5
	mov dl, 47
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	mov al, '*'
	call PRINT_AT

	mov dh, 6
	mov dl, 47
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	mov al, '*'
	call PRINT_AT

	mov dh, 7
	mov dl, 47
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	mov al, '*'
	call PRINT_AT

	mov dh, 8
	mov dl, 48
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	mov al, '*'
	call PRINT_AT

	mov dh, 9
	mov dl, 49
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	ret

PRINT_E2:
	mov dh, 5
	mov dl, 54
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT

	mov dh, 6
	mov dl, 54
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT

	mov dh, 7
	mov dl, 54
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT

	mov dh, 8
	mov dl, 54
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT

	mov dh, 9
	mov dl, 54
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	ret

PRINT_R:
	mov dh, 5
	mov dl, 61
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT

	mov dh, 6
	mov dl, 61
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	mov al, '*'
	call PRINT_AT

	mov dh, 7
	mov dl, 61
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT

	mov dh, 8
	mov dl, 61
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	mov al, '*'
	call PRINT_AT

	mov dh, 9
	mov dl, 61
	call SET_CURSOR
	mov al, '*'
	call PRINT_AT
	mov al, ' '
	call PRINT_AT
	call PRINT_AT
	call PRINT_AT
	mov al, '*'
	call PRINT_AT
	ret

; ================================================================================
; Game Over Screen
; ================================================================================
DRAW_GAME_OVER:
	call CLEAR_SCREEN

	mov ax, 0xb800
	mov es, ax
	mov di, 3*160 + 28*2
	mov si, MSG_FINAL_SCORE
	mov ah, 0x0E

PRINT_FINAL_SCORE_LABEL:
	lodsb
	cmp al, 0
	je PRINT_FINAL_SCORE_NUM
	stosw
	jmp PRINT_FINAL_SCORE_LABEL

PRINT_FINAL_SCORE_NUM:
	mov ax, [SCORE]
	call PRINT_DECIMAL

	call LONG_DELAY
	call LONG_DELAY

	call PRINT_G
	call LONG_DELAY
	call LONG_DELAY
	call PRINT_A
	call LONG_DELAY
	call LONG_DELAY
	call PRINT_M
	call LONG_DELAY
	call LONG_DELAY
	call PRINT_E
	call LONG_DELAY
	call LONG_DELAY
	call PRINT_O
	call LONG_DELAY
	call LONG_DELAY
	call PRINT_V
	call LONG_DELAY
	call LONG_DELAY
	call PRINT_E2
	call LONG_DELAY
	call LONG_DELAY
	call PRINT_R
	call LONG_DELAY
	call LONG_DELAY
	ret

; ================================================================================
; Main Program Entry Point
; ================================================================================
START:
	mov ax, 1100
	out 0x40, al
	mov al, ah
	out 0x40, al
	
	call INIT_RANDOM_SEED
	call INTRO_SCREEN
	mov ax, 0x1003
	mov bl, 1
	int 0x10
	mov dh, 25
	mov dl, 0

	call SET_CURSOR
	call CLEAR_SCREEN
	call DRAW_SCAPE
	call DRAW_FOREST
	call INIT_OPP_CAR
	call SAVE_SCREEN
	call RESTORE_SCREEN
	call DRAW_CAR

	in al,0x60

	cli

	xor ax,ax
	mov es,ax

	mov ax,[es:8*4]
	mov [OLD_INTERRUPT_ISR],ax
	mov ax,[es:8*4+2]
	mov [OLD_INTERRUPT_ISR+2],ax

	mov word[es:8*4],NEW_INTERRUPT_ISR
	mov [es:8*4+2],cs

	mov ax,[es:9*4]
	mov [OLD_KEYBOARD_ISR],ax
	mov ax,[es:9*4+2]
	mov [OLD_KEYBOARD_ISR+2],ax

	mov word[es:9*4],NEW_KEYBOARD_ISR
	mov [es:9*4+2],cs

	sti
GAME_LOOP:
	cmp word[STOP_GAME],1
	je RESTORE_INTERRUPTS
	call DELAY
	jmp GAME_LOOP

RESTORE_INTERRUPTS:
	cli
	xor ax,ax
	mov es,ax

	mov ax,[OLD_INTERRUPT_ISR]
	mov [es:8*4],ax
	mov ax,[OLD_INTERRUPT_ISR+2]
	mov [es:8*4+2],ax

	mov ax,[OLD_KEYBOARD_ISR]
	mov [es:9*4],ax
	mov ax,[OLD_KEYBOARD_ISR+2]
	mov [es:9*4+2],ax

	sti
	call DRAW_GAME_OVER
	mov ah, 0
	int 16h
	int 20h