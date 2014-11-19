BITS 32

extern kmain
global _start
global _higherhalf

extern kernel_phys
extern kernel_start
extern kernel_end

; the stack is 16KiB
section .stack
align 4
stack_bottom:
  resb 16384
stack_top:

section .preamble
; the page directory is actually computable at compile time
page_directory:
  ; bitwise "or" doesn't work on labels :c
  dd page_table_0 + 3
  ; fill the void between PDE #0 and PDE #896
  times (896 - 1) dd 0
  dd page_table_896 + 3
  ; fill the remainder of PDEs
  times (1024 - 896 - 1) dd 0

; the first page table is also computable at compile time
; it will identity-map the first 1MiB+16KiB of memory
; (BIOS stuff plus the .preamble section)
page_table_0:
%assign addr 0x0
%rep 260
  ; attributes: supervisor level, read + write, present
  dd addr | 3
  %assign addr addr + 4096
%endrep
  ; fill the remainder of the PTEs
  times (1024 - 260) dd 0

; this, sadly, can't be computed at compile time (or can it?)
page_table_896:
  resd 1024 ; reserve 4KiB

_start:
  ; set up the #896 page table
  mov eax, 0x0         ; counter
  mov ebx, kernel_phys ; address

  ; map 4MiB from the physical location to 0xe0000000
  .fill_table:
    mov ecx, ebx
    or  ecx, 3
    mov [page_table_896 + eax * 4], ecx
    add ebx, 0x1000
    inc eax
    cmp eax, 1024
    je .end
    jmp .fill_table
  .end:

  ; enable paging
  mov eax, page_directory
  mov cr3, eax

  mov eax, cr0
  or eax, 0x80000000
  mov cr0, eax

  jmp _higherhalf

section .text
_higherhalf:
  ; boot1 creates the `bootinfo' structure, populates it, and pushes a pointer
  ; to it to the stack (the pointer that's to be passed to `kmain')
  ; we have to remember the pointer's value because the kernel sets up it's
  ; own stack
  pop eax

  ; yup, right here
  mov esp, stack_top

  ; fix the `kernel_addr' field in the `bootinfo' structure to be the virtual
  ; address, not the physical one
  mov [eax], dword kernel_start

  ; we are now ready to actually execute C code
  ; calling kmain(eax)
  push eax
  call kmain

  ; in case the function returns
  cli
.halt:
  hlt
  jmp .halt

; vi: ft=nasm:ts=2:sw=2 expandtab

