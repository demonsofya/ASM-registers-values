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
                shr dx, 4           ; потому что нам надо память выделять а не параграфы

                inc dx
                int 21h


NewKeyboardInterrupt proc
        push ax
        push bx
        push es 

        xor ax, ax
        mov ah, 12h
        int 16h                 ; getting in ax info about shift/ctrl/alt/...
        
        in al, 60h              ; reading symbol from keyboard (for our ctrl+shift combination used only ah)
        cmp ax, 011fh           ; clt + left shift - 0100h | s - 1fh
        jne JumpOldInterrupt

        mov ax, 0b800h
        mov es, ax
        mov bx, 160d * 10 + 80d ; screen center
        
        push 6789h
        call RegValueToHex
    
    JumpOldInterrupt:
        xor bx, bx

        pop es
        pop bx
        pop ax

        db 0eah
        OldInterruptOffset dw 0
        OldInterruptSegment dw 0
        
        iret

;--------------------------
;1sr arg - value to turn to hex
;es:[bx] - where to print value
;
RegValueToHex proc
        push bp
        mov bp, sp

        push ax
        push bx
        push cx
        push dx

        mov ax, ss:[bp + 4]     ; value to turn to hex
        
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

        pop dx
        pop cx
        pop bx
        pop ax

        pop bp
        ret 2d

;--------------------------
;dl - from 0 to 15
;es:[bx] where to print
;bx += 2
;Destroy: dl, bx += 2
NumToOneHex proc
        cmp dl, 10
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


             