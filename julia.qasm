.include "4EachPixel.qasm"

.macro t1
    fmul r_zi, r_zr, r_zi;  fadd r_zr, r_xc, r_zr2     #zi=zr*zi       zr=zr*zr+xc
    fmul r_zi, r_zi, 2.0;   fsub r_zr, r_zr, r_zi2     #zi=2*zr[*zi]   zr=[zr*zr+xc]-zi*zi
    fmul r_zr2, r_zr, r_zr; fadd r_zi, r_zi,  r_yc     #zr2=zr*zr      zi=[2*zr*zi]+yc
    fmul r_zi2, r_zi, r_zi;                            #zi2=zi*zi
    fadd r_tmp_julia, r_zr2, r_zi2
    fsub.setf r_tmp_julia, 4.0, r_zr2
    add.ifnn r_result_julia, r_result_julia, 1
.endm   

:init_calc_color
.set r_xc, rb22
.set r_yc, rb23
.set r_nb_iter, rb26
.set r_julia_width, rb24
.set r_julia_height, rb25
.set NB_UNROLL, 16
.set LOG_NB_UNROLL, 4
.set r_color_decal, rb27
    mov r_xc, unif
    mov r_yc, unif
    mov r3, unif;   mov r2, 0.5
    mov ra20, r3
    shr r3, r3, LOG_NB_UNROLL
    add r3, r3, 1
    mov r_nb_iter, r3; 
    fmul r0, r_inv_width, r2;    
    fmul r1, r_inv_height, r2;
    fsub r_xc, r_xc, r0
    fsub r_yc, r_yc, r1
    mov r0, ra20
    itof r0, r0
    mov log, r0
    nop
    nop    
    mov r0, r4    
    ftoi  r_color_decal, r0; 
    mov r0, 8
    sub r_color_decal, r_color_decal, r0
    bra -, ra_link
    nop    
    nop
    nop

:calc_color
.set r_zr, r0
.set r_zi, r1
.set r_zr2, r2
.set r_zi2, r3
.set r_x_julia, ra20
.set r_y_julia, ra21
.set r_result_julia, ra22
.set r_tmp_julia, ra23
.set r_uncount_iter, ra24
.set r_tmp_julia2, ra25
    mov r0, r_x
    itof r_x_julia, r0;mov r0, r_y
    itof r_y_julia, r0;
    fmul r_x_julia, r_x_julia,  r_inv_width
    fmul r_y_julia, r_y_julia, r_inv_height
    fsub r_x_julia, r_x_julia, 0.5
    fsub r_y_julia, 0.5, r_y_julia
    fmul r_x_julia, r_x_julia, 2.0
    fmul r_y_julia, r_y_julia, 2.0
    
    mov r_zr, r_x_julia;mov r_result_julia,0
    fmul r_zr2, r_zr, r_zr; mov r_zi, r_y_julia
    fmul r_zi2, r_zi, r_zi; mov r_uncount_iter, r_nb_iter
    fmul r_zi, r_zr, r_zi;  fadd r_zr, r_xc, r_zr2   
:loop_iter_julia
    .rep i, NB_UNROLL
    fmul r_zi, r_zi, 2.0;   fsub r_zr, r_zr, r_zi2   
    fmul r_zr2, r_zr, r_zr; fadd r_zi, r_zi,  r_yc   
    fmul r_zi2, r_zi, r_zi; fadd r_tmp_julia2, r_xc, r_zr2                         
    fmul r_zi, r_zr, r_zi;  fadd r_tmp_julia, r_zr2, r_zi2
    fsub.setf r_tmp_julia, 4.0, r_zr2; mov r_zr, r_tmp_julia2
    add.ifnn r_result_julia, r_result_julia, 1
    .endr
    brr.alln -,:end_iter_julia
    nop
    nop
    nop
    sub.setf r_uncount_iter, r_uncount_iter, 1
    brr.anynz -, :loop_iter_julia
    nop
    nop
    fsub.setf -, 4.0, r_zr2
    mov.ifnn r_result_julia,0    
:end_iter_julia
    mov r1, 0xFF
    mov r0, r_result_julia
    and r0, r0, r1
.if BPP == 32
    mov r1, 0xFF000000
    or r0, r0, r1
    shl r1, r0,8
    or r0, r0, r1
    shl r1, r1, 8
    mov r_current_color, r0, r1
.elseif BPP == 16
    shr r0, r0, 3
    mov r1, r0
    shl r1, r1, 5
    or r1, r1, r0
    shl r1, r1, 6
    or r1, r1, r0
    or r_current_color, r_current_color, r1
.else
    mov r1, 0xFF
    and r0, r0, r1
    or r_current_color, r_current_color, r0
.endif
    bra -, ra_link
    nop
    nop
    nop

