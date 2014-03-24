BITS 16
ORG 0x7c00

jmp near boot1

%include "print.asm"
%include "utils.asm"

boot1:
  ; update the segment register
  xor ax, ax
  mov ds, ax

  ; set up the stack
  cli
  xor ax, ax
  mov ss, ax
  mov sp, 0x5c00
  sti

; 'enter' unreal mode
go_unreal:
  ; disable interrupts
  cli
  ; save the data segment
  push ds
  ; load the GDT
  lgdt [gdt]
  ; set the PE bit
  mov eax, cr0
  or  al, 1
  mov cr0, eax
  ; tell 386/486 not to crash
  jmp $+2
  ; select the code descriptor
  mov bx, 0x08
  mov ds, bx
  ; unset the PE bit, back to real mode
  and al, 0xfe
  mov cr0, eax
  ; restore the data segment
  pop ds
  ; enable interrupts
  sti

  ; save the drive number from which we've booted
  mov [bootdrv], dl

%ifdef DEBUG
  call puthex
  mov ah, 0eh
  mov al, ' '
  int 10h
%endif

  ; see if the a20 line is enabled, and enable it if it isn't
  call check_a20
  test ax, ax
  je enable_a20
  jmp get_drive_params

enable_a20:
  mov si, enable_a20_msg
  call putstr

  .1:
    ; try the BIOS
    mov ax, 0x2401
    int 0x15
    ; see if it worked
    call check_a20
    test ax, ax
    jne .end
    ; it didn't, carry on
  .2:
    ; try using the keyboard controller
    call enable_a20_via_kbd
    ; see if it worked
    call check_a20
    test ax, ax
    jne .end
    ; it didn't, carry on
  .3:
    ; try the Fast A20 Gate
    in al, 0x92
    test al, 2
    jne .end
    or al, 2
    and al, 0xFE
    out 0x92, al
    ; check if it worked
    call check_a20
    test ax, ax
    jne .end

    ; here, it seems it didn't work, which is a shame
    mov si, enable_a20_fail_msg
    call putstr
    jmp halt

  .end:

get_drive_params:
  ; fetch the drive geometry
  ;
  ; let's see if we're on a hardrive or a floppy
  ; if it's a hard drive, then we'll calculate/retrieve the values
  ; if it's a floppy, then we'll use the defaults
  cmp dl, 0x80
  jb .floppy

  ; here, it's a harddrive
%ifdef DEBUG
  mov si, hd_msg    ;
  call putstr       ; deleteme
%endif

  xor dx, dx
  xor cx, cx  ; zero out dx and cx
  ; call uncle BIOS
  mov ah, 8
  mov dl, [bootdrv]
  int 13h
  ; now dh contains the number of heads - 1, so let's retrieve it
  inc dh
  mov byte [number_of_heads], dh
  ; cl holds the sector number, but, only the first 6 bits contain the actual number
  and cx, 0x003f
  mov byte [sectors_per_track], cl
  jmp .end

.floppy:
  ; here, it's a floppy
%ifdef DEBUG
  mov si, floppy_msg
  call putstr
%endif

  mov byte [number_of_heads], 16
  mov byte [sectors_per_track], 63

.end:
;
; Load the superblock
;
reset_sblk:
  ; reset the boot drive
  xor ah, ah
  mov dl, [bootdrv]
  int 13h
  ; error, let's try again
  jc reset_sblk

calculate_chs:
  ; the primary superblock is 8KiB (16 sectors) wide, and is at
  ; offset 0x10000 (128 sectors), which makes it an LBA 128
  ; so yup, let's translate it into CHS

  ; temp     = LBA / sectors per track
  ; sector   = LBA % sectors per track + 1
  ; head     = temp % number of heads
  ; cylinder = temp / number of heads

  mov ax, 128         ; LBA / sectors per track
  div byte [sectors_per_track]
  xor dx, dx          ; dx will be the temp 'variable'
  mov dl, al          ; al = dl = LBA / sectors per track
                      ; ah = LBA % sectors per track
  inc ah              ; ah++
  mov [sector], ah    ; sector = ah

  mov ax, dx          ; temp / number of heads
  div byte [number_of_heads]
  mov [head], ah      ; head = ah = temp % number of heads
  mov [cylinder], al  ; cylinder = al = temp / number of heads

%ifdef DEBUG
; {{{
  call putnl
  xor dx, dx
  mov dl, [number_of_heads]
  call puthex
  call putnl

  mov dl, [sectors_per_track]
  call puthex
  call putnl
  call putnl

  ; print the CHS values
  xor dx, dx
  mov dl, [cylinder]
  call puthex
  call putnl

  mov dl, [head]
  call puthex
  call putnl

  mov dl, [sector]
  call puthex
  call putnl
  call putnl
; }}}
%endif

read_sblk:
  ; all right, calculations are done, now let's roll!
  ; load the super block into just above the bootloader
  mov ax, 0x05c0
  mov es, ax
  xor bx, bx          ; es:bx = 0x05c0:0x0000 (= 0x5c00)

  mov ah, 02h         ; the instruction
  mov al, 10h         ; load 16 sectors
  mov ch, [cylinder]  ; the calculated cylinder
  mov dh, [head]      ; the calculated head
  mov cl, [sector]    ; the calculated sector
  mov dl, [bootdrv]   ; the drive we've booted from
  int 13h             ; load!

  ; error, let's try again
  jc read_sblk

welcome:
  mov si, welcome_msg
  call putstr

  ; set up the segments
  mov ax, 0x0
  mov ds, ax
  mov si, 0x5c00

  ; fetch the superblock essentials
  ; ...with a handy macro!
%macro fetch 2
  mov eax, dword [si + %2]
  mov [fs_%1], eax
%endmacro

  fetch sblkno,    8
  fetch cblkno,    12
  fetch iblkno,    16
  fetch dblkno,    20
  fetch ncg,       44
  fetch bsize,     48
  fetch fsize,     52
  fetch frag,      56
  fetch fsbtodb,   100
  fetch cgsize,    160
  fetch ipg,       184
  fetch fpg,       188
  fetch size,      1080

; fetch is no more
%undef fetch

  ; d_bsize is not fetched, but calculated
  xor edx, edx
  mov eax, [fs_fsize]
  fsbtodb ebx, 1
  div dword ebx
  ; d_bsize = eax = fs_fsize / fsbtodb(1)
  mov [d_bsize], eax

  ; print a smiley face
  mov bx, 0x0f01
  mov eax, 0x0b8000
  mov word [ds:eax], bx

; traverse the cylinder groups in search for the kernel
; initialize the counter (0->fs_ncg)
mov ecx, 0

loop_through_cgs:
  jmp varsend
  ; space for some variables
  cgbase: dd 0
  cgimin: dd 0
  cgdmin: dd 0
  cgtod: dd 0
  phcgimin: dd 0
  phcgdmin: dd 0
  tell: dd 0
  inodesz: dw 0
  lba: dd 0
  c: db 0
  h: db 0
  s: db 0
  sectors_to_load: dd 0
  varsend:
  ; save the counter
  push ecx

  ; get the physical address of the current CG
  call cgloc
  mov [tell], eax

  ; get the physical address of the current CG's inode table
  call cginoloc
  mov [phcgimin], eax

  ; get the physical address of the current CG's data blocks start
  call cgdataloc
  mov [phcgdmin], eax

%ifdef DEBUG
; {{{
  mov si, cg_msg
  call putstr
  pop ecx
  mov al, cl
  push ecx
  call putdigit
  mov ah, 0xe
  mov al, ':'
  int 10h
  mov al, ' '
  int 10h
  mov edx, [tell]
  call puthex
  mov ah, 0xe
  mov al, ' '
  int 10h
  mov edx, [phcgimin]
  call puthex
  mov ah, 0xe
  mov al, ' '
  int 10h
  mov edx, [phcgdmin]
  call puthex
  call putnl
; }}}
%endif

  ; calculate the size of a single inode
  xor edx, edx
  mov eax, [phcgdmin]
  sub eax, [phcgimin]
  div dword [fs_ipg]
  mov [inodesz], ax

  ; calculate the LBA of the physical inodes address
  xor edx, edx
  mov eax, [phcgimin]
  mov ecx, 512
  div ecx
  ; LBA = eax = phcgimin / 512
  mov [lba], eax
  ; edx = phcgimin % 512

  ; calculate the number of sectors to load (we're going to be loading the
  ; inodes, 127 sectors at a time)
  xor eax, eax
  mov  ax, word [inodesz]
  mov ebx, [fs_ipg]
  mul dword ebx
  ; edx:eax = inode size * fs_ipg
  xor edx, edx
  mov ecx, 0x7f
  div dword ecx
  mov [sectors_to_load], eax
  xor ecx, ecx   ; this be our counter (0->sectors_to_load)

  fetch_sectors:
    ; save the register
    push ecx

    ; calculate the CHS values for the current LBA
    mov eax, [lba]
    xor edx, edx
    xor ecx, ecx
    mov cl, [sectors_per_track]
    div dword ecx
    ; eax = LBA / sectors_per_track
    ; edx = LBA % sectors_per_track
    inc dl
    and dl, 0x3f
    mov [s], dl
    xor edx, edx
    xor ecx, ecx
    mov cl, [number_of_heads]
    div dword ecx
    ; eax = eax / number of heads
    ; edx = eax % number of heads
    mov [h], dl
    mov [c], al
    and ax, 0x300
    shr ax, 2
    or al, byte [s]
    mov [s], al

%if 0
%ifdef DEBUG
; {{{
pop ecx
    mov eax, ecx
push ecx
    ;xor edx, edx
    ;mov ecx, 0x75
    ;div ecx
    ;cmp edx, dword 0
    ;ja skip_printing
    cmp eax, dword 0x2
    jbe do_the_printing
    cmp eax, dword 0x1fa00
    jb skip_printing
    do_the_printing:
; {{{
    mov ah, 0xe
    mov al, ' '
    int 10h
    mov si, lba_msg
    call putstr
    mov edx, [lba]
    call puthex
    mov ah, 0xe
    mov al, ' '
    int 10h
    pop ecx
    mov edx, ecx
    push ecx
mov si, ecx_msg
call putstr
    call puthex
    mov ah, 0xe
    mov al, ' '
    int 10h
    xor edx, edx
mov si, c_msg
call putstr
    mov dl, [c]
    call puthex
    mov ah, 0xe
    mov al, ' '
    int 10h
mov si, h_msg
call putstr
    mov dl, [h]
    call puthex
    mov ah, 0xe
    mov al, ' '
    int 10h
mov si, s_msg
call putstr
    mov dl, [s]
    call puthex
    call putnl
; }}}
    skip_printing:
; }}}
%endif
%endif

    ; TODO: traverse the 127 loaded sectors and see for our inode

    ; restore the counter
    pop ecx
    ; counter++
    inc ecx
    ; increase the current LBA to be loaded by 127
    mov eax, [lba]
    add eax, 0x7f
    mov [lba], eax
    ; see if the counter is less than the number of sectors to load
    cmp ecx, dword [sectors_to_load]
    ; if it is less then go back to the beginnig of the loop
    jb fetch_sectors

  ; restore the counter
  pop ecx
  ; counter++
  inc ecx
  ; see if the counter is less than fs_ncg
  cmp ecx, [fs_ncg]
  ;cmp ecx, 1
  ; if it is then go back to the beginning of the loop
  jb loop_through_cgs

nice_halt:
  mov si, goodbye_msg
  call putstr

halt:
  cli
  hlt

;
; The Global Descriptor Table
;
gdt_data:
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

; Superblock variables
;
; offset of superblock in filesystem
fs_sblkno: dd 0
; offset of cylinder block
fs_cblkno: dd 0
; offset of inode blocks
fs_iblkno: dd 0
; offset of first data after CG
fs_dblkno: dd 0
; # of cylinder groups
fs_ncg: dd 0
; size of basic blocks in fs
fs_bsize: dd 0
; size of fragment blocks in fs
fs_fsize: dd 0
; number of framents in a block
fs_frag: dd 0
; fstbtodb and dbtofsb shift constant
fs_fsbtodb: dd 0
; cylinder group size
fs_cgsize: dd 0
; inodes per group
fs_ipg: dd 0
; blocks per group * fs_frag
fs_fpg: dd 0
; number of blocks in fs
fs_size: dq 0
; number of data blocks in fs
fs_dsize: dq 0
; device bsize
d_bsize: dd 0

; number of heads
number_of_heads: db 0
; sectors per track
sectors_per_track: db 0
; when loading the kernel, this is the head value
head: db 0
; this is the cylinder number
cylinder: db 0
; and the sector
sector: db 0
; number of the drive we have booted from
bootdrv: db 0

; the messages
floppy_msg: db 'Floppy.', 0xd, 0xa, 0
hd_msg: db 'Hard drive.', 0xd, 0xa, 0
cg_msg: db 'CG #', 0
lba_msg: db 'lba:', 0
ecx_msg: db 'ecx:', 0
c_msg: db 'c:', 0
h_msg: db 'h:', 0
s_msg: db 's:', 0
enable_a20_msg: db 'Enabling the a20 line', 0xd, 0xa, 0
enable_a20_fail_msg: db 'Failed to enable the a20 line!', 0xd, 0xa, 0
welcome_msg: db 'Quidquid Latine dictum, sit altum videtur.', 0xd, 0xa, 0xd, 0xa, 0
goodbye_msg: db 0xd, 0xa, 'Sit vis vobiscum', 0xd, 0xa, 0

; make it be 127 sectors wide
times 512*127-($-$$) db 0

; vi: ft=nasm:ts=2:sw=2 expandtab

