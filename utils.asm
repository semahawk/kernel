; a few handy macros

; saves the registers
%macro regsave 0
  push ax
  push bx
  push cx
  push dx
%endmacro
; restores the registers
%macro regrest 0
  pop dx
  pop cx
  pop bx
  pop ax
%endmacro

%macro print 0
  regsave
  mov ah, 0xE
  mov al, 0xD
  int 10h
  mov al, 0xA
  int 10h
  regrest
%endmacro

%macro print 1
  regsave
  ; set the registers
  mov si, word %1
  mov ah, 0xE

  %%print_char:
    lodsb
    cmp al, 0
    je %%done
    int 10h
    jmp %%print_char

  %%done:
    regrest
%endmacro

; {{{ print a given, single number as uppercase hexadecimal
%macro print_digit 1
  mov al, %1
  cmp al, 10
  jl %%ten_less
%%ten_more:
  add al, 55
  jmp %%print
%%ten_less:
  add al, 48
%%print:
  mov ah, 0xE
  int 10h
%endmacro
; }}}

; {{{ print a word in decimal format
%macro print_dec 1
  regsave
  mov dx, word %1

  %%print_5:
    mov cl, 0

    %%repeat_5:
      cmp dx, 9999
      jle %%print_4
      sub dx, 10000
      inc cl
      jmp %%repeat_5

  %%print_4:
    cmp cl, 0
    je %%repeat_4
    add cl, 48
    mov ah, 0xE
    mov al, cl
    int 10h
    mov cl, 0

    %%repeat_4:
      cmp dx, 999
      jle %%print_3
      sub dx, 1000
      inc cl
      jmp %%repeat_4

  %%print_3:
    cmp cl, 0
    je %%repeat_3
    add cl, 48
    mov ah, 0xE
    mov al, cl
    int 10h
    mov cl, 0

    %%repeat_3:
      cmp dx, 99
      jle %%print_2
      sub dx, 100
      inc cl
      jmp %%repeat_3

  %%print_2:
    cmp cl, 0
    je %%repeat_2
    add cl, 48
    mov ah, 0xE
    mov al, cl
    int 10h
    mov cl, 0

    %%repeat_2:
      cmp dx, 9
      jle %%print_1
      sub dx, 10
      inc cl
      jmp %%repeat_2

  %%print_1:
    cmp cl, 0
    je %%repeat_1
    add cl, 48
    mov ah, 0xE
    mov al, cl
    int 10h
    mov cl, 0

    %%repeat_1:
      cmp dx, 0
      jle %%done
      sub dx, 1
      inc cl
      jmp %%repeat_1

  %%done:
    add cl, 48
    mov ah, 0xE
    mov al, cl
    int 10h
    regrest
%endmacro
; }}}

; {{{ print a word in hexadecimal format
%macro print_hex 1
  regsave
  mov dx, word %1

  mov bx, 0
  mov cx, 0
  mov ah, 0xE
  mov al, '0'
  int 10h
  mov al, 'x'
  int 10h          ; print the leading '0x'

  mov cx, dx
  and cx, 0xF000   ; fetch the first nibble
  shr cx, 12       ; shift twelve bits right
  print_digit cl   ; print it
  mov cx, dx
  and cx, 0x0F00   ; fetch the second nibble
  shr cx, 8        ; shift eight bits right
  print_digit cl   ; print it
  mov cx, dx
  and cx, 0x00F0   ; fetch the third nibble
  shr cx, 4        ; shift four bits right
  print_digit cl   ; print it
  mov cx, dx
  and cx, 0x000F   ; fetch the fourth nibble
                   ; no need to shift
  print_digit cl   ; print it
%endmacro
; }}}

; vi: ft=nasm:ts=2:sw=2 expandtab
