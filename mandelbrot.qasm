.include "4EachPixel.qasm"

:init_calc_color
.set r_xc, rb22
.set r_yc, rb23
.set r_mandel_width, rb24
.set r_mandel_height, rb25
.set r_nb_iter, rb26
.set NB_UNROLL, 16
.set LOG_NB_UNROLL, 4
.set r_color_decal, rb27
    mov r_xc, unif
    mov r_yc, unif
    mov r0, unif;
    mov r1, unif;    mov r2, 0.5
    mov r3, unif
    mov ra20, r3
    shr r3, r3, LOG_NB_UNROLL
    add r3, r3, 1
    mov r_nb_iter, r3; 
    fmul r_mandel_width, r0, r_inv_width
    fmul r_mandel_height, r1, r_inv_height
    fmul r0, r0, r2;    
    fmul r1, r1, r2;
    fsub r_xc, r_xc, r0
    fsub r_yc, r_yc, r1;    
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
.set r_x_mandel, ra20
.set r_y_mandel, ra21
.set r_result_mandel, ra22
.set r_tmp_mandel, ra23
.set r_uncount_iter, ra24
.set r_tmp_mandel2, ra25
    mov r0, r_x
    itof r_x_mandel, r0;mov r0, r_y
    itof r_y_mandel, r0;
    fmul r1, r_x_mandel, r_mandel_width
    mov r2,r_mandel_height
    fmul r2, r_y_mandel, r2
    mov r_result_mandel,0

    fadd r_x_mandel, r1, r_xc
    fadd r_y_mandel, r2, r_yc
    mov r_zr, r_x_mandel;mov r_zi2, 0
    mov r_uncount_iter, r_nb_iter;mov r_zi, 0
:loop_iter_mandelbrot
    .rep i, NB_UNROLL
    fmul r_zi, r_zi, 2.0;   fsub r_zr, r_zr, r_zi2         #zi=2*zr[*zi]    zr=[zr*zr+xc]-zi*zi
    fmul r_zr2, r_zr, r_zr; fadd r_zi, r_zi,  r_y_mandel     #zr2=zr*zr    zi=[2*zr*zi]+yc
    fadd r_tmp_mandel2, r_x_mandel, r_zr2;   fmul r_zi2, r_zi, r_zi;                    #zi2=zi*zi
    fadd r_tmp_mandel, r_zr2, r_zi2;    fmul r_zi, r_zr, r_zi 
    fsub.setf r_tmp_mandel, 4.0, r_zr2;     mov r_zr, r_tmp_mandel2
    add.ifnn r_result_mandel, r_result_mandel, 1
    .endr
    brr.alln -,:end_iter_mandelbrot
    nop
    nop
    nop
    sub.setf r_uncount_iter, r_uncount_iter, 1
    brr.anynz -, :loop_iter_mandelbrot
    nop
    nop
    fsub.setf -, 4.0, r_zr2
    mov.ifnn r_result_mandel,0    
:end_iter_mandelbrot
    mov r1, 0xFF
    mov r0, r_result_mandel
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


