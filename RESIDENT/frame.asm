.286
.model tiny
.code
locals @@

org 100h


Start:
        ; ------------ IRQ 1 - KEYBOARD ------------

        mov ax, 3509h                   ; get interrupt vector (es - segment, bx - offset)
        int 21h

        mov Old09Ofs, bx                ; save old offset
        mov bx, es
        mov Old09Seg, bx                ; save old segment

        cli                             ; block interrupts

        mov bx, 4 * 09h
        push 0                          ; es = 0 - PSP
        pop es

        mov es:[bx], offset HotkeyFrame09

        push cs                         ; ax = cs
        pop  ax

        mov es:[bx+2], ax               ; segment

        sti                             ; allow interrupts

        ; ------------ IRQ 0 - TIMER ------------

        mov ax, 3508h                   ; get interrupt vector (es - segment, bx - offset)
        int 21h

        mov Old08Ofs, bx                ; save old offset
        mov bx, es
        mov Old08Seg, bx                ; save old segment

        cli                             ; block interrupts

        mov bx, 4 * 08h
        push 0                          ; es = 0 - PSP
        pop es

        mov es:[bx], offset RefreshFrame08

        push cs                         ; ax = cs
        pop  ax

        mov es:[bx+2], ax               ; segment

        sti                             ; allow interrupts

        ; ------------ PROGRAM TERMINATION ------------
        mov dx, offset EndOfProgram     ; terminate and stay resident
        shr dx, 4
        inc dx
        mov ax, 3100h
        int 21h

;-----------------------------------------------------------------------------------
; Int 09h extension which draws frame with current register values when hotkey is pressed
;
; Destr: -
; QUESTION: is it ok to push ax once and then pop it twice (in different places)?
;-----------------------------------------------------------------------------------
HotkeyFrame09   proc
        push ax                 ; save ax

        in  al, 60h
        cmp al, HOTKEY_SCN_CODE
        jne @@Std09

        mov cs:IsFrameOn, 1d    ; raise flag

        in  al, 61h             ; blink Most Significant Bit (MSB) in kybd port controller
        or  al, 80h
        out 61h, al
        and al, 7fh
        out 61h, al

        mov al, 20h             ; set end of interrupt
        out 20h, al

        pop ax                  ; recover ax

        iret

@@Std09:
        pop ax                  ; recover ax
                db 0eah ; jmp far
Old09Ofs        dw 0d   ; offset
Old09Seg        dw 0d   ; segment

HotkeyFrame09   endp

;-----------------------------------------------------------------------------------
; Int 08h extenstion which refreshes the frame if IsFrameOn flag is raised
;
; Notes:
;       ds = cs inside this procedure
;-----------------------------------------------------------------------------------
RefreshFrame08  proc
        cmp cs:IsFrameOn, 0d    ; if flag is down - jmp to std Int 08
        je @@Std08
                                ; else draw frame
        ; ------------------------------------------------------------------
        push ss es ds sp bp di si dx cx bx ax
        mov bp, sp              ; bp is restored later (see big pop section)

        push cs                 ; ds = cs
        pop ds

        push 0b800h             ; es = 0b800h - vmem
        pop  es

        call DrwFrm
        call WrtRegs

        pop ax bx cx dx si di bp sp ds es ss
        ; ------------------------------------------------------------------

                                ; finally do std Int 08 no matter what
@@Std08:
                db 0eah ; jmp far
Old08Ofs        dw 0d   ; offset
Old08Seg        dw 0d   ; segment

RefreshFrame08  endp

;-----------------------------------------------------------------------------------
; given the frame is drawn, write text with registers and their values inside
;
; Entry:
;       AH - color attribute
;       SI - registers control string offset
;
; Assumes:
;       ES = 0b800h - VMem
;       DS = CS
; Destr: -
;-----------------------------------------------------------------------------------
WrtRegs proc
        push bx cx di si

        call SetFrmBase         ; bx = top left corner of the frame
        call SetBXNewLine       ; go next line
        add  bx, 4d             ; skip border and space symbol

        mov di, bx
        mov si, offset RegNames ; axbxcx....

        mov  cx, NREGS - 2      ; all the regs as in turbodebugger except ip, cs
@@Next:
        call WrtReg             ; write ax: dead
        call SetBXNewLine       ; go next line
        mov  di, bx
        loop @@Next

        ; Carefully print cs and ip vals.
        ; This is done outside of the loop bcs cs and ip are in reverse order in stack

        ; PRINT CS
        add bp, 2               ; skip ip temporarily
        call WrtReg
        call SetBXNewLine
        mov  di, bx

        ; PRINT IP
        sub bp, 4               ; subtract 4 = 2 + 2 (bp was increased by 2 in wrt reg)
        call WrtReg
        call SetBXNewLine
        mov  di, bx

        pop si di cx bx

        ret

WrtRegs endp

;-----------------------------------------------------------------------------------
;Entry:
;       AH - color attribute
;       SI - registers control string offset
;       DI - beginning position on screen
;
;Assumes:
;       ES = 0b800h - VMem
;       DS = CS
;       BP points to position in stack where saved register values are
;Destr: DI, SI, BP
;-----------------------------------------------------------------------------------
WrtReg  proc
        push ax

        ; -------------------------- WRITE REGISTER NAME --------------------------
        lodsb                           ; frst letter
        stosw

        lodsb
        stosw                           ; scnd letter

        mov byte ptr es:[di], 58d       ; ':' colon
        add di, 2

        mov byte ptr es:[di], 32d       ; whitespace
        add di, 2

        ; -------------------------- WRITE REGISTER VALUE --------------------------

        call WrtRegVal

        pop ax

        ret
WrtReg  endp

;-----------------------------------------------------------------------------------
;Entry:
;       BP - index of register in stack (ax is at 0)
;
;Assumes:
;       ES = 0b800h
;       DS = CS
;Destr: BP
;-----------------------------------------------------------------------------------
WrtRegVal       proc
        push ax dx si

        mov ax, [bp]            ; ax = ss:[bp]
        mov dx, ax              ; save original reg value

        mov si, offset HexNums

        ; ------------ | * _ _ _ | ------------

        mov al, ah
        xor ah, ah

        and al, 11110000b
        shr al, 4d

        mov si, offset HexNums
        add si, ax
        mov ah, 4eh
        lodsb
        stosw

        ; ------------ | * * _ _ | ------------

        mov ax, dx              ; restore original reg value
        mov al, ah
        xor ah, ah
        and al, 00001111b

        mov si, offset HexNums
        add si, ax
        mov ah, 4eh
        lodsb
        stosw

        ; ------------ | * * * _ | ------------

        mov ax, dx              ; restore original reg value
        xor ah, ah
        and al, 11110000b
        shr al, 4d

        mov si, offset HexNums
        add si, ax
        mov ah, 4eh
        lodsb
        stosw

        ; ------------ | * * * * | ------------

        mov ax, dx              ; restore original reg value
        xor ah, ah
        and al, 00001111b

        mov si, offset HexNums
        add si, ax
        mov ah, 4eh
        lodsb
        stosw

        add bp, 2               ; bp points to next register in stack   !!!

        pop si dx ax

        ret
WrtRegVal       endp

;-----------------------------------------------------------------------------------
;Entry:
;       AH - color attribute
;       SI - control string offset
;
;Assumes:
;       ES = 0b800h - VMem
;       DS = CS
;Destr: -
;-----------------------------------------------------------------------------------
DrwFrm  proc
        push bx cx si di

        mov ah, CLR_ATTR        ; set color attribute
        mov si, offset CntrlString

        call SetFrmBase         ; bx points to top left corner of the frame
        mov  di, bx

        call WrtLine            ; first line
        call SetBXNewLine
        mov  di, bx

        mov cx, F_HIGHT
        add si, 3               ; after sub si will be the same
@@Next:
        sub  si, 3              ; offset = beginning of mid section of Control String
        call WrtLine            ; mid line
        call SetBXNewLine
        mov  di, bx

        loop @@Next

        call WrtLine            ; last line

        pop di si cx bx

        ret
DrwFrm  endp

;-----------------------------------------------------------------------------------
;Entry:
;       AH - color attribute
;       DS - segment where Control String is
;       SI - offset to Control String
;       DI - beginning position on screen
;Assumes:
;       ES = 0b800h - VMem
;
;Destr: DI, SI, DF
;-----------------------------------------------------------------------------------
WrtLine proc
        push ax cx

        cld

        lodsb   ; first symbol of the line
        stosw

        lodsb
        mov cx, F_WIDTH
@@Next:
        stosw   ; middle symbol
        loop @@Next

        lodsb   ; last symbol
        stosw

        pop cx ax

        ret

WrtLine endp

;-----------------------------------------------------------------------------------
; set bx to point to position on screen where frame begins (top left corner)
;Assumes: -
;Returns:
;       bx - required position on screen
;Destr: bx
;-----------------------------------------------------------------------------------
SetFrmBase      proc
        mov  bx, T_OFFSET
        imul bx, 2 * W_WDTH
        add  bx, L_OFFSET
        add  bx, L_OFFSET
        and  bx, not 1h

        ret
SetFrmBase      endp

;-----------------------------------------------------------------------------------
; set bx to point to the same position of the next line
;Assumes: -
;Returns:
;       bx - required position on screen
;Destr: bx
;-----------------------------------------------------------------------------------
SetBXNewLine      proc

        add bx, 2 * 80d
        ret
SetBXNewLine     endp

;-----------------------------------------------------------------------------------
;
;
;-----------------------------------------------------------------------------------
WrtDbgMsg       proc
        push ax dx ds

        push cs ; ds = cs
        pop  ds

        mov dx, offset DbgString
        mov ah, 09h
        int 21h

        pop  ds dx ax
        ret
WrtDbgMsg       endp

CntrlString     db 0c9h, 0cdh, 0bbh, 0bah, 32d, 0bah, 0c8h, 0cdh, 0bch

RegNames        db  'ax'
                db  'bx'
                db  'cx'
                db  'dx'
                db  'si'
                db  'di'
                db  'bp'
                db  'sp'
                db  'ds'
                db  'es'
                db  'ss'
                db  'cs'
                db  'ip'
HexNums         db '0123456789abcdef'
DbgString       db 'debug is debil bug$'

NREGS           equ 13d
HOTKEY_SCN_CODE equ 83d        ; 'del' scan code
W_WDTH          equ 80d
CLR_ATTR        equ 4eh

IsFrameOn       db 0d

T_OFFSET        dw 1d
L_OFFSET        dw 1d
F_HIGHT         dw 13d
F_WIDTH         dw 11d

EndOfProgram:

end     Start
