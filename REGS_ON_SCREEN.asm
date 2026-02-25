.model tiny
.code
org 100h

reg_back_color equ 4eh

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
                shl dx, 4           ; потому что нам надо память выделять а не параграфы

                inc dx
                int 21h




;------------------------
;
;
;------------------------
NewKeyboardInterrupt proc
        push sp
        push ax
        push bx
        push es 
        push dx

        xor ax, ax
        mov ah, 12h
        int 16h                 ; getting in ax info about shift/ctrl/alt/...
        
        in al, 60h              ; reading symbol from keyboard (for our ctrl+shift combination used only ah)
        cmp ax, 011fh           ; clt - 0100h | s - 1fh
        jne JumpOldInterrupt

        pop ax

        push ax

        call PrintRegisters
    
    JumpOldInterrupt:

        pop dx
        pop es
        pop bx
        pop ax
        pop sp

        db 0eah
        OldInterruptOffset dw 0
        OldInterruptSegment dw 0
        
        iret
;--------------------------

;--------------------------
PrintRegisters proc
        ;push sp
        ;push ip 
        ;push cs 
        ;push ss 
        ;push es
        ;push ds 
        push bp
        push di
        push si 
        push dx
        push cx
        push bx 
        push ax

        mov ax, 0b800h
        mov es, ax
        mov bx, 160d * 10 + 80d ; screen center
        
        mov dx, 6178h                   ; "ax"
        call PrintRegNameFromMemory

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
        add bx, 160d

        ret 2d
;--------------------------



;--------------------------
;1sr arg - value to turn to hex
;es:[bx] - where to print value
;save everything
;-------------------------
RegValueToHex proc
        push bp
        mov bp, sp

        push bx

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

        mov ax, ss:[bp + 8]     ; value to turn to hex
        
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

        pop bx

        pop bp
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


ProgramEndPoint:

end     Start


             