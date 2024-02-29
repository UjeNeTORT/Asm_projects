.model tiny
.code
.286

locals @@

org 100h

Start:
        cld
        mov bx, 0b800h
        mov es, bx
        xor bx, bx

        call RdCmdLn

        call SetTLOfst

        mov ah, CLR_ATTRIBUTE   ; color attribute
        mov si, OFFST_FRAME

        call WrtFrm

        mov ax, 4c00h
        int 21h

;---------------------------------------------------------
;Entry:
;       AH - color attribute
;       SI - control string offset
;Assumes:
;       ES = 0b800h - VMem
;
;Destr:
;       CX, SI
;---------------------------------------------------------
WrtFrm  proc

        call SetOfst
        call WrtLine    ; first line

        mov cx, F_HIGHT
        add si, 3       ; after sub si will be the same
@@Next:
        sub si, 3       ; offset = beginning of mid section of Control String

        call NxtOfst
        call WrtLine    ; mid line

        loop @@Next

        call NxtOfst
        call WrtLine    ; last line

        mov si, OFFST_TEXT
        call WrtText

        ret
        endp

;------------------------------------
;Entry:
;       AH - color attribute
;       SI - offset to Control String
;       DI - beginning position on screen
;Assumes:
;       ES = 0b800h - VMem
;
;Destr: AL, DI, SI, CX
;------------------------------------
WrtLine proc

        cld
        push cx
        xor cx, cx

        lodsb
        stosw

        lodsb
        mov cx, F_WIDTH
@@Next:
        stosw
        loop @@Next

        lodsb
        stosw

        pop cx

        ret
        endp

;------------------------------------
;calc top and left offset variables so as to
;place frame is in the center
;Returns:
;
;Destr:
;------------------------------------
SetTLOfst       proc
        mov ax, W_WDTH
        sub ax, F_WIDTH
        shr ax, 1
        mov word ptr L_OFFSET, ax

        mov ax, W_HGHT
        sub ax, F_HIGHT
        shr ax, 1
        mov word ptr T_OFFSET, ax

        ret
        endp

;------------------------------------
;set DI to point to beginning of the new line
;Returns:
;       BX = DI - line beginning offset
;            in VMem since which first line begins
;Destr: BX, DI
;------------------------------------
SetOfst proc

        mov bx, T_OFFSET
        dec bx          ; to make the frame closer to top than bottom
        imul bx, 80d
        imul bx, 2d
        add bx, L_OFFSET
        add bx, L_OFFSET
        sub bx, 2       ; to make the frame closer to the left than right

        mov di, bx

        ret
        endp

;------------------------------------
;set DI to point to beginning of the text section
;Returns:
;       DI - position since which frame text begins
;Destr: BX
;------------------------------------
SetOfstText     proc
        call SetOfst    ; di = frame beginning

        mov bx, F_HIGHT
        shr bx, 1h
        imul bx, 160d
        add di, bx      ; di = beginning of middle line

        add di, 2       ; di = beginning of the inside of the frame mid line

        push di         ; preparations b4 strlen call
        mov di, ds
        mov es, di      ; set es = ds
        mov di, si      ; set string offset

        call MyStrLen

        mov di, 0b800h
        mov es, di      ; recover es
        pop di          ; recover di

        mov bx, ax      ; string len
        shr bx, 1h
        shl bx, 1h
        add di, F_WIDTH ; move to center of the frame
        sub di, bx      ; shift left

        ret
        endp

;------------------------------------
;set DI to point to beginning of the next line
;Returns:
;       BX = DI - beginning index
;            in VMem since which line begins
;Destr: BX, DI
;------------------------------------
NxtOfst proc

        add bx, W_WDTH
        add bx, W_WDTH

        mov di, bx

        ret
        endp

;------------------------------------
;write text in the top left angle (or middle*) of the frame
;Entry:
;       SI - offset to the string
;Assumes:
;       ES = 0b800h - VMem
;Destr: BX, DI
;------------------------------------
WrtText proc
        call    SetOfstText

        cmp byte ptr [si], 0dh  ; \n
        je @@EndFunc
@@Next:
        movsb

        cmp byte ptr [si], 0dh  ; \n
        je @@EndFunc

        push ax
        mov al, CLR_ATTRIBUTE
        mov byte ptr es:[di], al
        pop  ax

        inc di
        cmp byte ptr [si], 0dh  ; \n
        jne @@Next

@@EndFunc:
        ret
        endp

;------------------------------------
;Entry:
;Assumes:
;       ES = 0b800h
;
;Destr: AX, BX, CX, DX
;
;------------------------------------
RdCmdLn proc
        xor ax, ax
        xor bx, bx
        xor cx, cx
        xor dx, dx

        mov si, 80h
        mov cl, [si]
        mov si, 81h

        inc si ; skip first space

        call GetNmbr    ; get frame width
        mov F_WIDTH, dx

        call GetNmbr    ; get frame hight
        mov F_HIGHT, dx

        call GetHex     ; get frame color attribute
        mov CLR_ATTRIBUTE, dl

        cmp byte ptr [si], '*'
        je @@NewFrame

        call GetNmbr    ; get number of control string

        mov ax, offset CntrlStringArr
        imul dx, 9
        add ax, dx
        mov OFFST_FRAME, ax

jmp @@FuncEnd
@@NewFrame:

        inc si ; skip *
        mov OFFST_FRAME, si

        add si, 9
        inc si ; skip space

@@FuncEnd:
        mov OFFST_TEXT, si

        ret
        endp

;------------------------------------
;Entry:
;       SI - offset to number beginning
;Returns:
;       DX - desired number
;Destr: AX, DX
;------------------------------------
GetNmbr proc
        xor ax, ax
        xor dx, dx
@@Next:
        cmp byte ptr [si], ' '
        je @@Stop

        imul dx, 10d
        lodsb
        sub ax, '0'
        add dx, ax

        jmp @@Next
@@Stop:

        inc si ; skip space

        ret
        endp

;------------------------------------
;Entry:
;       SI - offset to number beginning
;
;Returns:
;       DX - desired number
;Destr: AX, DX
;------------------------------------
GetHex  proc
        xor ax, ax
        xor dx, dx
@@Next:
        cmp byte ptr [si], ' '
        je @@Stop

        imul dx, 16d
        lodsb
        cmp al, 'a'
        jae @@ProcessLetter

        sub ax, '0'
        cmp ax, 10
        jae @@Error

jmp @@EndNext
@@ProcessLetter:
        sub ax, 'a'
        add ax, 10
        cmp ax, 16
        jae @@Error
@@EndNext:
        add dx, ax

        jmp @@Next
@@Stop:

        inc si ; skip space

        ret

@@Error:
        mov ax, 4c01h
        int 21h

        ret ; desperate ret
        endp

;-------------------
;Entry:
;	DI - offset to a string
;Assumes:
;	ES = DS
;Returns:
;	AX - string length
;Destr:
;	CX, AX
;-------------------
MyStrLen	proc
	cld	; clear direction flag

	xor cx, cx
	dec cx	; cx = -1

	mov al, 0d
@@Next:
	scasb	; cmp al, es:[di++]
	loopne @@Next

	neg cx
	dec cx ; retrieve string length
	dec cx ; dont con

	mov ax, cx

	ret
	endp

CntrlStringArr  db '┌─┐│ │└─┘'
		db '╔═╗║ ║╚═╝'
                db '+-+| |+-+'
                db 3h,3h,3h,3h,20h,3h,3h,3h,3h
                db 0dh,0dh,0dh,0dh,20h,0dh,0dh,0dh,0dh
                db 3h,3h,3h,3h,20h,3h,3h,3h,3h

CLR_ATR db 4eh
T_OFST  dw 5d
L_OFST  dw 5d

F_HGHT  dw 10d
F_WDTH  dw 50d

W_HGHT  dw 25d
W_WDTH  dw 80d

CLR_ATTRIBUTE   db ?
OFFST_FRAME     dw ?
OFFST_TEXT      dw ?
F_HIGHT         dw ?
F_WIDTH         dw ?

T_OFFSET        dw ?
L_OFFSET        dw ?

end	Start
