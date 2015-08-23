#need external functions:
#   :init_calc_color
#   :calc_color
#see julia.qasm or mandelbrot.qasm 

.set NB_X_PACKET, 5
.set BPP, 8

    brr -, :begin
    nop
    nop
    nop

.include "vc4.qinc"
.include "helper.qinc"


.const r_x, ra3
.const r_y, ra4
.const r_vpm_row, ra5
.const r_vw_row, ra6
.const r_current_color, ra7
.const r_x_base_packet , ra8
.const r_framebuffer, rb6
.const r_inv_width, rb1
.const r_inv_height, rb2
.const r_pitch, rb3
.const r_width, rb4
.const r_height, rb5

.if BPP == 8
.set nb_color_loop, 4
.elseif BPP == 16
.set nb_color_loop, 2
.elseif BPP == 32
.set nb_color_loop, 1
.endif

:begin
    init_base
    mov r0, unif
    add r_framebuffer, r0, unif
    mov r_pitch, unif
    mov r_width, unif
    mov r_height, unif
    mov r_inv_width, unif
    mov r_inv_height, unif    
    brr ra_link, :init_calc_color
    nop
    nop
    nop
    mov r0, elem_num
.if BPP == 8
    mov r1, 18
    shl r0, r0, r1
.elseif BPP == 16
    mov r1, 17
    shl r0, r0, r1
.else
    mov r1, 16
    shl r0, r0, r1
.endif
    MUTEX_ACQ
    sub.setf -, r_qpu, 0
    brr.allnz -, :not_first_qpu
    nop
    nop
    nop
    mov vw_setup, vpm_setup(1, 1, 0xA00|62)
    mov vpm, r0
:not_first_qpu
    MUTEX_REL
    mov r0, vpm_setup(1, 1, h32(0,0))
    mul24 r1, r_qpu, 5

    or r_vpm_row, r0, r1
    mov r0, vdw_setup_0(NB_X_PACKET, 16, dma_h32(0,0))
    shl r1, r1, 7
    or r_vw_row, r0, r1
    nop
    nop
    nop


:loop_render    
    MUTEX_ACQ
    mov vr_setup, vpm_setup(1, 1, 0xA00|62)
    mov -, vr_wait
    mov r0, vpm
    mov ra21, 0xFFFF 

    mov ra20, 16
    and r_y, r0, ra21
    shr r_x, r0, ra20
    sub.setf -, r_y, r_height
    brr.allnn -, :exit_with_mutex
    mov r1, r_y
    mov r0, r_x
    mov r2, 16*NB_X_PACKET*nb_color_loop
    add r0, r0, r2
    sub.setf -, r0, r_width
    brr.allnz -, :gogogo
    nop
    nop
    nop
    
    
.if BPP == 8
    shl r0, elem_num, 2
.elseif BPP == 16
    shl r0, elem_num, 1
.else
    mov r0, elem_num
.endif
    add r1, r1, 1
    sub.setf -, r_height, r1    
    brr.allnn -, :gogogo
    nop
    nop
    nop
    brr.allnn -, :exit_with_mutex

    nop
    nop
    nop
    
:gogogo
     shl r0, r0, ra20
    or r0, r1, r0    
    mov vw_setup, vpm_setup(1, 1, 0xA00|62)
    mov -, vw_wait
    mov vpm, r0    
    mov vw_setup, r_vpm_row
    MUTEX_REL

    
    mov r_current_color, 0
    nop

 
.rep i, nb_color_loop*NB_X_PACKET
    brr ra_link, :calc_color
    nop
    nop
    nop

    
    mov r0, BPP
    ror r_current_color, r_current_color, r0
.if (i&(nb_color_loop-1)) == nb_color_loop-1
    mov -, vw_wait
    mov vpm, r_current_color
    mov r_current_color, 0
.endif
.if (i&(nb_color_loop-1)) != nb_color_loop-1
    add r_x, r_x, 1
.else
    mov r0, 16*nb_color_loop-nb_color_loop+1
    add r_x, r_x, r0
.endif
.endr

#needed ? dead lock if not...!!!
    mov vw_setup, r_vw_row
    mov vw_setup, r_vpm_row
#end needed ? dead lock if not...!!!


#send NB_X_PACKET
    mov r0, NB_X_PACKET*16*nb_color_loop
    sub r0, r_x, r0
    mul24 r1, r_y, r_pitch
.if BPP == 32
    shl r0, r0, 2
.elseif BPP == 16
    shl r0, r0, 1
.endif
    add r0, r0, r1
    add r0, r_framebuffer, r0
    mov vw_setup, r_vw_row
    mov vw_setup, vdw_setup_1(0)

    mov vw_addr, r0

#.endm
    brr -, :loop_render
    nop
    nop
    nop
