#include <kernel/smp.h>

org KERNEL_TRAMPOLINE_LOAD_ADDR
bits 16

start:
    jmp 0x0:trampoline

align KERNEL_TRAMPOLINE_VARS_OFFSET
kernel_pdir: dd 0x0
unique_stack_id: dd 0x0
kmain_secondary_cores: dd 0x0

trampoline:
    ; update the segment register
    xor ax, ax
    mov ds, ax

enter_protected_mode:
    cli
    lgdt [gdt]
    mov eax, cr0
    or al, 1
    mov cr0, eax
    jmp 0x08:protected_mode

bits 32
protected_mode:
    mov eax, 0x10
    mov ds, eax
    mov es, eax
    mov fs, eax
    mov gs, eax
    mov ss, eax

enable_paging:
    mov eax, dword [kernel_pdir]
    mov cr3, eax

    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

; reference: http://ethv.net/workshops/osdev/notes/notes-5
find_my_stack:
    mov eax, dword [unique_stack_id]
    mov ebx, eax
    inc ebx
    lock cmpxchg dword [unique_stack_id], ebx
    jnz find_my_stack

    dec ebx
    mov esp, ebx
    inc esp
    shl esp, KERNEL_TRAMPOLINE_STACK_SIZE_LOG2
    add esp, KERNEL_TRAMPOLINE_STACKS_START_ADDR

enter_kmain_for_secondary_cores:
    mov eax, dword [0x0fee00020]
    shr eax, 24
    push eax

    mov edx, dword [kmain_secondary_cores]
    call edx

.halt:
    cli
    hlt

    ; just for good measure
    jmp .halt
;
; The Global Descriptor Table
;
gdt_data:
; {{{
; the null selector
  dq 0x0           ; nothing!

; the code selector: base = 0x0, limit = 0xfffff
  dw 0xffff        ; limit low (0-15)
  dw 0x0           ; base low (0-15)
  db 0x0           ; base middle (16-23)
  db 10011010b     ; access byte
  db 11001111b     ; flags + limit (16-19)
  db 0x0           ; base high (24-31)

; the data selector: base = 0x0, limit = 0xfffff
  dw 0xffff        ; limit low (0-15)
  dw 0x0           ; base low (0-15)
  db 0x0           ; base middle (16-23)
  db 10010010b     ; access byte
  db 11001111b     ; flags + limit (16-19)
  db 0x0           ; base high (24-31)
; THE actual descriptor
gdt_end:
gdt:
  dw gdt_end - gdt_data - 1 ; sizeof gdt
  dd gdt_data
; }}}

; vi: ft=nasm:ts=2:sw=2:expandtab
