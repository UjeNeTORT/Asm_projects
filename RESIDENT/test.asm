.286
.model tiny
.code

locals @@

org 100h

; при старте печатает свой cs и раскладывает по регистрам 111 2222 3333 и т д
Start:

        mov ah, 09h
        mov dx, offset RegString
        int 21h

        push cs ; dx = cs
        pop  bx

        call PrintW
@@Next:
        mov ax, 1111h
        mov bx, 2222h
        mov cx, 3333h
        mov dx, 4444h

        in al, 60h
        cmp al, 1d ; esc
        jne @@Next

        mov ax, 4c00h
        int 21h

;-----------------------------------------------------------------------------------
; print 2-byte word
; Entry:
;       bx - word
;
;-----------------------------------------------------------------------------------
PrintW proc
        push ax bx dx si ds

        push cs ; ds = cs
        pop  ds

        mov ah, 02h     ; Int 21h func - display char

        ; ------------ | * _ _ _ | ------------

        mov ax, bx
        mov si, offset HexNums

        mov al, ah
        xor ah, ah
        and al, 0f0h
        shr al, 4

        add si, ax

        mov ah, 02h
        mov dl, [si]
        int 21h

        ; ------------ | * * _ _ | ------------

        mov ax, bx
        mov si, offset HexNums

        mov al, ah
        xor ah, ah
        and al, 0fh

        add si, ax

        mov ah, 02h
        mov dl, [si]
        int 21h

        ; ------------ | * * * _ | ------------

        mov ax, bx
        mov si, offset HexNums

        xor ah, ah
        and al, 0f0h
        shr al, 4

        add si, ax

        mov ah, 02h
        mov dl, [si]
        int 21h

        ; ------------ | * * * * | ------------

        mov ax, bx
        mov si, offset HexNums

        xor ah, ah
        and al, 0fh

        add si, ax

        mov ah, 02h
        mov dl, [si]
        int 21h

        pop  ds si dx bx ax

        ret

HexNums db '0123456789abcdef'

PrintW endp

RegString db 'cs = $'
end     Start

