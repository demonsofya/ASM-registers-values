.model tiny
.code
org 100h

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

        mov ax, 0b800h
        mov es, ax
        mov bx, 160d * 10 + 80d ; screen center 

        xor ax, ax
        mov ah, 4eh             ; yellow on red 
        
        in al, 60h              ; reading symbol from keyboard 
        mov es:[bx], ax 

        xor bx, bx

        pop es
        pop bx
        pop ax

        db 0eah
        OldInterruptOffset dw 0
        OldInterruptSegment dw 0
        
        iret

ProgramEndPoint:

end     Start


             