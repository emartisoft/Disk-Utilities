load_off        equ     $400
load_size       equ     $1200

start:
        ; Standard DOS bootblock header
        dc.b    'D','O','S',0   ; signature
        dc.l    0               ; checksum (filled later)
        dc.l    880             ; dummy root block index

        ; Save trackdisk ioreq for later use
        move.l  a1,-(sp)

        ; Allocate chip memory for the data we're loading
        move.l  #load_size,d0   ; size
        moveq   #3,d1           ; MEMF_PUBLIC | MEMF_CHIP
        jsr     -$c6(a6)        ; exec.AllocMem
        move.l  d0,-(sp)
        bne     .load
        add.l   #8,sp
        moveq   #-1,d0
        rts

        ; Load data
.load:  move.l  4(sp),a1
.retry: move.l  (sp),$28(a1)    ; io_Data
        move.l  #load_size,$24(a1) ; io_Length
        move.l  #load_off,$2c(a1)  ; io_Offset
        move.w  #2,$1c(a1)      ; io_Command = CMD_READ
        jsr     -$1c8(a6)       ; exec.DoIO
        move.l  4(sp),a1
        move.b  $1f(a1),d0      ; check io_Error
        bne     .retry          ; ...retry if failed

        ; Decrypt data (xorshift)
        move.l  (sp),a0
        move.l  #$46414d45,d0   ; w
        move.l  #$075bcd15,d2   ; x
        move.l  #$159a55e5,d3   ; y
        move.l  #$1f123bb5,d4   ; z
        move.w  #(load_size/4)-1,d1
.dec:   move.l  d2,d5           ; t = x
        lsl.l   #8,d5
        lsl.l   #3,d5
        eor.l   d2,d5           ; t = x ^ (x << 1))
        move.l  d3,d2           ; x = y
        move.l  d4,d3           ; y = z
        move.l  d0,d4           ; z = w
        move.l  d5,d6
        lsr.l   #8,d6
        eor.l   d6,d5           ; t = t ^ (t >> 8)
        move.l  d0,d6
        move.w  #0,d6
        swap    d6
        lsr.w   #3,d6           ; w >> 19
        eor.l   d6,d5
        eor.l   d5,d0           ; w = w ^ (w >> 19) ^ (t ^ (t >> 8))
        eor.l   d0,(a0)+
        dbf     d1,.dec

        ; We have loaded code from disk: Flush caches if possible
        cmp.w   #37,$14(a6)     ; exec.lib_version >= 37
        bmi     .done
        jsr     -$27c(a6)       ; exec.CacheClearU

        ; Clean up our stack and jump at what we just loaded
.done:  movem.l (sp)+,a0-a1
        jmp     (a0)

        dc.b    "Cracked by KAF June 2011"
