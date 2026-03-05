.model tiny
.code
org 100h

Start:      ;putting some values in regs
        mov ax, 1234h
        mov bx, 5678h
        mov cx, 1111h
        mov dx, 2222h
        mov si, 3333h
        mov di, 4444h
        mov bp, 5555h
        push 6666h
        pop ds
        push 7777h
        pop es
        push 8888h
        pop ss

    compare_cycle:
        in al, 60h              
        cmp al, 01h             ; comparing with esc code
        je end_programm

        jmp compare_cycle

    end_programm:
        mov ax, 4c00h
		int 21h

        endp

end			Start
        
