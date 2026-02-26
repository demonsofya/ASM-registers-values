; на таймере сохраняем рамку -> копируем в draw buffer -> сравниваем с save - до обновления рамочки 
; сравниваем всегда до обновления рамки - ловим что кто-то засрал между прерываниями

.model tiny
.code
org 100h

reg_back_color equ 4eh

screen_width equ 160d

ramka_x_cord equ 10d 
ramka_y_cord equ 2d

Start:          int 09h

                mov ax, 3509h
                int 21h
                mov OldInterruptOffset, bx
                mov OldInterruptSegment, es

                xor ax, ax
                mov es, ax          ; es - interruptions

                mov bx, 4 * 09h     ; - 9th interruption 
                cli                 ; stop interrupting 
                mov es:[bx], offset NewKeyboardInterrupt

                mov ax, cs          ;  current code segment
                mov es:[bx + 2], ax ; потому что ебучий литл ендиан
                sti                 ; continue interrupting 

                int 09h

                mov ax, 3100h       ; end + save memory
                mov dx, offset ProgramEndPoint
                shr dx, 4           ; потому что нам надо память выделять а не параграфы

                inc dx
                int 21h




;------------------------
;
;
;------------------------
NewKeyboardInterrupt proc
        push bp
        mov bp, sp

        push sp
        push ax
        push bx
        push es 
        push dx
        push bp
        push cx

        xor ax, ax
        mov ah, 12h
        int 16h                 ; getting in ax info about shift/ctrl/alt/...
        
        in al, 60h              ; reading symbol from keyboard (for our ctrl+shift combination used only ah)
        cmp ax, 011fh           ; clt - 0100h | s - 1fh
        jne JumpOldInterrupt

        mov bx, ss:[bp + 4]     ; ip value

        pop ax
        push ax

        call PrintRegisters
        mov ax, 0b800h
        mov es, ax
        call DrawRectangleRamka
    
    JumpOldInterrupt:
        pop cx
        pop bp
        pop dx
        pop es
        pop bx
        pop ax
        pop sp

        pop bp

        db 0eah
        OldInterruptOffset dw 0
        OldInterruptSegment dw 0
        
        iret
;--------------------------

;--------------------------
PrintRegisters proc
        push sp
        push bx         ; ip 
        push cs 
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

        mov bp, sp

        mov ax, 0b800h
        mov es, ax
        mov bx, ramka_y_cord * screen_width + ramka_x_cord ; screen center

        mov cx, 13d                      ; registers count

        lea di, reg_names
print_one_reg:
        mov dx, cs:[di]
        xchg dl, dh                     ; little endian
        call PrintRegNameFromMemory
        add di, 2
        loop print_one_reg

        ret
        
        mov dx, 6178h                   ; "ax" ||| di = offset ax_name -> mov es:[bx], [di] <- ne rabotaet nihuya otomy chto dosbox huyna
        call PrintRegNameFromMemory     ;                                                                               ne uveren.

        mov dx, 6278h                   ; "bx"
        call PrintRegNameFromMemory

        mov dx, 6378h                   ; "cx"
        call PrintRegNameFromMemory

        mov dx, 6478h                   ; "dx"
        call PrintRegNameFromMemory

        mov dx, 7369h                   ; "si"
        call PrintRegNameFromMemory

        mov dx, 6469h                   ; "di"
        call PrintRegNameFromMemory

        mov dx, 6270h                   ; "bp"
        call PrintRegNameFromMemory

        ret
;--------------------------


;--------------------------
;dx - symbols
;
;--------------------------
PrintRegNameFromMemory proc
        mov es:[bx], dh       
        mov es:[bx+1], reg_back_color
        add bx, 2

        mov es:[bx], dl       
        mov es:[bx+1], reg_back_color
        add bx, 2
        
        call RegValueToHex

        sub bx, 4
        add bx, screen_width

        ret 2d
;--------------------------



;--------------------------
;1sr arg - value to turn to hex
;es:[bx] - where to print value
;save everything
;-------------------------
RegValueToHex proc
        push bx
        push cx

    PrintSpaceAndRavno:
        mov es:[bx], 20h        ; space
        mov es:[bx+1], reg_back_color
        add bx, 2

        mov es:[bx], 3dh        ; =
        mov es:[bx+1], reg_back_color
        add bx, 2

        mov es:[bx], 20h        ; space
        mov es:[bx+1], reg_back_color
        add bx, 2

        mov ax, ss:[bp + 2]     ; value to turn to hex
        
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
        add bp, 2

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

        add dl, 48d
        jmp print_one_hex_num

    letter_hex_num:
        add dl, 87
        
    print_one_hex_num:
        mov es:[bx], dl
        mov es:[bx+1], reg_back_color

        add bx, 2
        ret
;--------------------------



;--------------------------
;draw ramka ah (symbol = 00) color cx width and si high
; function that exsists only for next task
;Expect:   es = 0b800h
;destroy:  di, si, dx,
;save:     bx, ax, cx
;Return:   nothing
;--------------------------
DrawRectangleRamka proc
        push ax
        push bx

        xor di, di

        mov cx, 13d
        mov si, 17d

    ; counting ramka position
        xchg ax, di     ;---- saving to mul
        xor ax, ax
        add ax, screen_width * ramka_y_cord - screen_width - 2; center of 2nd string
        sub ax, cx      ; center of str
        and ax, not 1       ; making num even, cause colors and symbols will change in opposite
        xchg ax, di     ;di - correct address

        xor al, al      ; no symbol
        mov dx, cx      ; saving cx

;first string
        rep stosw       ; printing first empty string
        mov cx, dx
        sub di, dx
        sub di, dx
        add di, screen_width

        stosw           ; printing second string with tacing
        mov al, 201d    ; угловой символ 
        stosw
        mov cx, dx
        sub cx, 4
        mov al, 205d    ; прямой символ типо =
        rep stosw
        mov al, 187d    ; угловой символ
        stosw
        xor al, al
        stosw

        sub dx, 4       ; going on next string
        mov cx, dx
        sub di, dx
        sub di, dx
        sub di, 8
        add di, screen_width

draw_all_strings:
        stosw           ; first empty symbol
        mov al, 186d    ; вертикальная окантовка
        stosw
        xor al, al
        rep stosw       ; остальные пустые символы
        mov al, 186d    ; вертикальная окантовка 
        stosw
        xor al, al
        stosw

        mov cx, dx      
        sub di, dx
        sub di, dx
        sub di, 8
        add di, screen_width    
        dec si
        cmp si, 0
        jg draw_all_strings 

;last string
        xor al, al
        stosw
        mov al, 200d    ; угловой символ
        stosw
        mov cx, dx
        mov al, 205d    ; прямой горизонтальный символ
        rep stosw
        mov al, 188d    ; угловой символ
        stosw
        xor al, al
        stosw
        sub di, dx
        sub di, dx
        sub di, 8
        add di, screen_width

        mov cx, dx
        add cx, 4
        xor al, al
        rep stosw

        pop bx
        pop ax

        ret
;--------------------------



reg_names db "axbxcxdxsibibpdsessscsipsp"

ProgramEndPoint:

end     Start


             