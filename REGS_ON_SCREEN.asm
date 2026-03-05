; на таймере сохраняем рамку -> копируем в draw buffer -> сравниваем с save - до обновления рамочки 
; сравниваем всегда до обновления рамки - ловим что кто-то засрал между прерываниями

.model tiny
.code
org 100h

PRINT_DL_VAL_END_COLOR macro 
        mov es:[bx], dl       
        mov es:[bx+1], REG_BACK_COLOR
        add bx, 2
        endm

REG_BACK_COLOR equ 4eh

SCREEN_WIDTH equ 160d

RAMKA_X_CORD equ 10d 
RAMKA_Y_CORD equ 2

REGS_COUNT equ 13d
RAMKA_WIDTH equ 15d

Start:      ;changing keyboard interrupt
        mov ax, 3509h
        int 21h
        mov OldKeyboardInterruptOffset, bx
        mov OldKeyboardInterruptSegment, es

        xor ax, ax
        mov es, ax          ; es - interruptions

        mov bx, 4 * 09h     ; - 9th interruption 
        cli                 ; stop interrupting 
        mov es:[bx], offset NewKeyboardInterrupt

        mov ax, cs          ;  current code segment
        mov es:[bx + 2], ax ; потому что ебучий литл ендиан
        sti                 ; continue interrupting 


    ;changing timer interrupt
        mov ax, 3508h
        int 21h
        mov OldTimerInterruptOffset, bx
        mov OldTimerInterruptSegment, es

        xor ax, ax
        mov es, ax          ; es - interruptions

        mov bx, 4 * 08h     ; - 8th interruption 
        cli                 ; stop interrupting 
        mov es:[bx], offset NewTimerInterrupt

        mov ax, cs          ;  current code segment
        mov es:[bx + 2], ax ; потому что ебучий литл ендиан
        sti                 ; continue interrupting 

    ;saving memory and end program
        mov ax, 3100h       ; end + save memory
        mov dx, offset ProgramEndPoint
        shr dx, 4           ; потому что нам надо память выделять а не параграфы

        inc dx
        int 21h



;------------------------
;New keyboard interrupt function
;printing ramka with regs on screen if Ctrl + S
;hide ramka on Ctrl + A
;saving all
;expect nothing
;------------------------
NewKeyboardInterrupt proc
	;saving ax old value                          
        push ax

        xor ax, ax
        mov ah, 12h
        int 16h                 ; getting in ax info about shift/ctrl/alt/...
        
        in al, 60h              ; reading symbol from keyboard (for our ctrl+shift combination used only ah)
        cmp ax, 011fh           ; clt - 0100h | s - 1fh 
        jne closing_ramka

        cmp [ramka_flag], 1h 
        je jmp_old_keyboard_interrupt

		mov [ramka_flag], 1h    ; ramka is on

        push es di si ax bx cx dx
        mov ax, 0b800h
        mov es, ax
        mov [saving_printing_buffer_flag], 0    ; 0 - saving ramka
		call SaveOrPrintBufferFunc
        mov [saving_printing_buffer_flag], 2
        call SaveOrPrintBufferFunc
        pop dx cx bx ax si di es

		jmp jmp_old_keyboard_interrupt

    closing_ramka:
        cmp ax, 011eh           ; clt - 0100h | a - 1eh
		jne jmp_old_keyboard_interrupt

		mov [ramka_flag], 0h    ; ramka is off

        push es di si ax bx cx dx  ; saving regs
		mov ax, 0b800h
        mov es, ax
		mov [saving_printing_buffer_flag], 1    ; 1 - printing ramka
		call SaveOrPrintBufferFunc
        pop dx cx bx ax si di es

	jmp_old_keyboard_interrupt:
        pop ax
	;jumping on old 09 interrupt
        db 0eah
        OldKeyboardInterruptOffset dw 0
        OldKeyboardInterruptSegment dw 0
        
        iret
;--------------------------



;--------------------------
;expect: es = 0b800h  | last 13 positions in stack are regs
;printing REGS_COUNT regs from memory started with dp position
;--------------------------
PrintRegNameFromMemory proc
	;printing regs
        mov bx, RAMKA_Y_CORD * SCREEN_WIDTH + RAMKA_X_CORD      ; regs start cord
        mov cx, REGS_COUNT                                      ; registers count

        lea di, reg_names                                       ; regs offset

    print_one_reg:
        mov dx, cs:[di]

	;print one reg from memory      
        PRINT_DL_VAL_END_COLOR

        xchg dl, dh            
        PRINT_DL_VAL_END_COLOR
        
        call RegValueToHex

        sub bx, 4
        add bx, SCREEN_WIDTH

        add di, 2
        loop print_one_reg

        ret 
;--------------------------



;--------------------------
;1sr arg - value to turn to hex
;es:[bx] - where to print value
;save everything
;-------------------------
RegValueToHex proc
        push bx
        push cx

        mov dl, ' '        ; space                     ; ПОМЕНЯЙ 20h НА ' ' !!!!!
        PRINT_DL_VAL_END_COLOR

        mov dl, '='        ; =                          ; ТОЖЕ
        PRINT_DL_VAL_END_COLOR

        mov dl, ' '        ; space                     ; ТОЖЕ
        PRINT_DL_VAL_END_COLOR

        mov ax, ss:[bp]     	; value to turn to hex
        
        mov ch, ah
        shr ch, 4               ; ch = ax % 16^3
        mov dl, ch
        call NumToOneHex        ; dl = ch 

        shl ch, 4
        sub ah, ch              ; ah = ax % 16^2 but less then 16 like 2nd hex num
        mov dl, ah
        call NumToOneHex

        mov cl, al
        shr cl, 4               ; cl = ax % 16 like 3rd hex num
        mov dl, cl
        call NumToOneHex

        shl cl, 4
        sub al, cl              ; al = ax but less then 16 like 4th hex num
        mov dl, al
        call NumToOneHex

        pop cx
        pop bx
        add bp, 2                   ; ПОДПИШИ, 2 ЧЕГО - d ИЛИ h. ПРОСЛЕДИ ЗА ЭТИМ ВЕЗДЕ, ГДЕ ЕСТЬ ЦИФРЫ

        ret
;--------------------------



;--------------------------
;Printing one value from stack as hex num (as one hex num)
;dl - from 0 to 15
;es:[bx] where to print
;bx += 2
;Destroy: dl, bx += 2
;---------------------------
NumToOneHex proc
        cmp dl, 9d
        jg letter_hex_num

        add dl, '0'                                 ; if it is 0-9
        jmp print_one_hex_num                       

    letter_hex_num:
        add dl, 'a' - 10                                 ; 87 = 'a' - 10                     
        
    print_one_hex_num:                              ; У ТЕБЯ УЖЕ 4 РАЗ ВСТРЕЧАЕТСЯ ТАКИЕ 3 СТРОЧКИ НИЖЕ (3 РАЗА ВСТРЕЧАЛИСЬ В ПРЕДЫДУЩЕЙ ПРОЦЕДУРЕ).
        PRINT_DL_VAL_END_COLOR

        ret
;--------------------------


; НИХУЯ НЕ ЯСНО, ЧЕ ТАКОЕ ah. ВТОРУЮ СТРОЧКУ КОММЕНТА МОЖНО И УБРАТЬ
;--------------------------
;draw ramka REG_BACK_COLOR color RAMKA_WIDTH width and REGS_COUNT high
;Expect:   es = 0b800h
;destroy:  di, si, dx, bx, ax, cx
;save:     nothing
;Return:   nothing
;--------------------------
DrawRectangleRamka proc
        mov cx, RAMKA_WIDTH		; reg string width
        mov si, REGS_COUNT      ; ramka height = regs count

    ; counting ramka position
        mov di, SCREEN_WIDTH * (RAMKA_Y_CORD - 2) + RAMKA_X_CORD - 6; begin of ramka coordinate 

        xor al, al      ; no symbol
        mov ah, REG_BACK_COLOR

	;first two strings
        rep stosw       ; printing first empty string
        add di, SCREEN_WIDTH - RAMKA_WIDTH * 2

        mov dx, 0c9bbh  ; c9 - верхний левый угловой символ, bb - правый верхний угловой символ
        mov ch, 205d    ; прямой символ похожий на '='
        call PrintOneRamkaString    ; printing second string

    ; cycle for middle of ramka
	draw_all_strings:
        mov dx, 0babah  ; вертикальная окантовка в два полу-регистра сразу
        mov ch, 0h

        call PrintOneRamkaString

        dec si
        cmp si, 0
        jg draw_all_strings 

	;last two strings
        mov dx, 0c8bch  ; c8 - левый нижний угловой символ, bc - правый нижний угловой символ
        mov ch, 205d    ; прямой символ типо '='
        call PrintOneRamkaString    ; предпоследняя строка

        mov cx, RAMKA_WIDTH
        xor al, al
        rep stosw       ; last string

        ret
;--------------------------


;--------------------------
;printing string with empty-1st-middle-2nd-empty style (stosw-stosw-rep stosw-stosw-stosw)
;Expect: es:[di] - where to printout ramka
;Entry: dh - left symbol ; dl - right symbol ; ch - middle symbol
;Destroy: al cx di
;Return: di - start position in new line
;--------------------------
PrintOneRamkaString proc
        xor al, al
        stosw           ; printing second string with tacing   
        mov al, dh      ; левый символ
        stosw
        mov al, ch      ; средний символ
        mov cx, RAMKA_WIDTH - 4
        rep stosw
        mov al, dl      ; правый символ
        stosw
        xor al, al
        stosw

        add di, SCREEN_WIDTH - RAMKA_WIDTH * 2

        ret
;--------------------------


;--------------------------
;New timer interrupt function
;printing ramka if ramka_flag is 1, or just going to old interrupt
;--------------------------
NewTimerInterrupt proc
		cmp [ramka_flag], 1
		jne jump_old_timer_interrupt

	;saving registers that would ba changed and pushing it to stack to printout
		push sp                ; cs and ip already in stack  
        push ss
        push es
        push ds 
        push bp                 
        push di
        push si 
        push dx
        push cx
        push bx 
        push ax

        mov ax, 0b800h
        mov es, ax

        call CmpDrawBufferAndScreen ; сравниваем рамки
        call DrawRectangleRamka     ; рисуем рамку
        
		mov bp, sp
        call PrintRegNameFromMemory ; выводим регистры

		mov [saving_printing_buffer_flag], 2
        call SaveOrPrintBufferFunc
    
        pop ax
        pop bx
        pop cx
        pop dx
        pop si
        pop di
        pop bp
        pop ds
        pop es
        pop ss
        pop sp

	jump_old_timer_interrupt:
		db 0eah
        OldTimerInterruptOffset dw 0
        OldTimerInterruptSegment dw 0
        
        iret
;--------------------------




;--------------------------
; If saving_printing_buffer_flag = 1, printing buffer to visual memory; or saving screen in buffer
;Saving buffer from screen to save_buffer 
;Print save_buffer on screen
;Destroy: di ax bx cx dx
;Save: nothing
;Return: nothing
;--------------------------
SaveOrPrintBufferFunc proc 
		mov di, SCREEN_WIDTH * (RAMKA_Y_CORD - 2) + RAMKA_X_CORD - 6; begin of ramka coordinate       
		lea bx, save_buffer    
        lea si, draw_buffer 
        mov dx, REGS_COUNT + 4  ; ramka height                                                                                     

save_print_all_ramka:
		mov cx, RAMKA_WIDTH

        cmp [saving_printing_buffer_flag], 0
        je save_one_string 
        cmp [saving_printing_buffer_flag], 2
        je draw_one_string

	print_one_string:
    ;printing ramka
		mov ax, cs:[bx]
		mov es:[di], ax
		add di, 2
		add bx, 2
		loop print_one_string 
          
        jmp end_one_string
        
    save_one_string:   
    ;saving ramka                     
		mov ax, es:[di]
		mov cs:[bx], ax
		add di, 2
		add bx, 2
		loop save_one_string 

        jmp end_one_string 

    draw_one_string:
    ;moving screen to draw buffer  
        mov ax, es:[di]
		mov cs:[si], ax
		add si, 2
		add di, 2
		loop draw_one_string    
                                       
    end_one_string:                                                              
        add di, SCREEN_WIDTH - RAMKA_WIDTH * 2    
		sub dx, 1                                                        
		cmp dx, 0                                                        
		jg save_print_all_ramka

		ret
;--------------------------


;--------------------------
;Compare draw buffer and screen. If difference, print screen symbol in save & draw buffer
;Destroy: di ax bx cx dx
;Save: nothing
;Return: nothing
;--------------------------
CmpDrawBufferAndScreen proc
        mov di, SCREEN_WIDTH * (RAMKA_Y_CORD - 2) + RAMKA_X_CORD - 6; begin of ramka coordinate       
		lea bx, draw_buffer 
        lea si, save_buffer                                                                         
		mov dx, REGS_COUNT + 4  ; ramka height  

compare_string:
        mov cx, RAMKA_WIDTH

    compare_symbol:
        mov ax, es:[di]
        cmp ax, cs:[bx]
        je go_to_next_symbol

        mov cs:[bx], ax
        mov cs:[si], ax

    go_to_next_symbol:
        add di, 2
        add si, 2
        add bx, 2

        loop compare_symbol
        
        sub di, RAMKA_WIDTH * 2                                          
		add di, SCREEN_WIDTH                                             
                                                                         
		sub dx, 1                                                        
		cmp dx, 0                                                        
		jg compare_string

        ret
;--------------------------




reg_names db "ax"
          db "bx"
          db "cx"
          db "dx"
          db "si"
          db "di"
          db "bp"
          db "ds"
          db "es"
          db "ss"
          db "sp"
          db "ip"
          db "cs"          

ramka_flag dw 0                     ; is ramka on screen 

saving_printing_buffer_flag dw 0    ; 0 - saving, 1 - printing, 2 - from screen to draw buffer

save_buffer dw 600 dup(0)		; выделяем памяти на 17 строк по 15 символов - наша рамка
                                ; ЭТО МЕНЬШЕ 500: 17 * 15 = 255
draw_buffer dw 600 dup(0)

ProgramEndPoint:



end     Start


             