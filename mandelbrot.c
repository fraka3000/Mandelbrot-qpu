#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <linux/fb.h>
#include <linux/kd.h>
#include <linux/ioctl.h>
#include <time.h>
#include "mailbox.h"

#define GPU_QPUS 12
#define NB_FRAMES 256

#define QPU_DUMP_SIZE 16*GPU_QPUS*4
#define QPU_MEM_SIZE 4096*4
#define GPU_MEM_FLG 0xC // cached=0xC; direct=0x4
#define GPU_MEM_MAP 0x0 // cached=0x0; direct=0x20000000
#define PI 3.14159f
#define X_MANDEL -0.7445f//0.001643721971153f//
#define Y_MANDEL 0.124f//0.822467633298876f //
#define INITIAL_SIZE_MANDEL 4.f

unsigned int program[] =
{
#ifdef MANDELBROT
    #include "mandelbrot.hex"
#endif
#ifdef JULIA    
    #include "julia.hex"
#endif    
};

typedef union int_to_float_to_int
{
    unsigned char uc[4];
    char c[4];
    unsigned short us[2];
    short s[2];
    unsigned int ui;
    int i;
    float f;
} int_to_float_to_int;


unsigned Microseconds(void) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return ts.tv_sec*1000000 + ts.tv_nsec/1000;
}

unsigned SwapFB(Frame_Buffer_Desc fbd, int mb, unsigned n){
    int xfb, yfb;
    unsigned pb = 0;
    if (n){
        xfb = 0;
        yfb = fbd.height;
    }
    else{
        xfb = 0;
        yfb = 0;
        pb = fbd.height * fbd.pitch;
    }
    set_frame_buffer_pos(mb, &xfb, &yfb);
    return pb;
}

#define as_gpu_address(x) (unsigned) gpu_pointer + ((void *)x - arm_pointer)
int main(int argc, char *argv[])
{
    int mb = mbox_open();
    int i, n_frame;
    int qpu_enabled = 0;

    // hide cursor
    char *kbfds = "/dev/tty0";
    int kbfd = open(kbfds, O_WRONLY);
    if (kbfd >= 0) {
        ioctl(kbfd, KDSETMODE, KD_GRAPHICS);
    }
    else {
        printf("Could not open %s.\n", kbfds);
    }



//init frame buffer
    Frame_Buffer_Desc fbd;
    fbd.width = 640    ;
    fbd.height = 480;
    fbd.v_width = fbd.width;
    fbd.v_height = fbd.height * 2;
    fbd.bpp = 8;

    if (!create_frame_buffer(mb, &fbd))
    {
        fbd.memory_size = 0;
        printf("error: can't create frame buffer\n");
        goto cleanup;
    }
    unsigned int palette[256];
    palette[0] = 0;
    for (i = 1;i < 256;++i)
    {
        float f = PI * i / 256.f;

        int r = (int)(cos(f) * 255);
        int g = (int)abs(cos(f + PI / 3.f) * 255);
        int b = (int)abs(cos(f + 2.f * PI / 3.f) * 255);

        r = r < 0 ? 0 : r;
        g = g < 0 ? 0 : g;
        b = b < 0 ? 0 : b;
        palette[i] =  (r << 16) | (g << 8) | b;
    }
/*
    unsigned qpu_palette[12] = {0, 0xFF, 0xFF00, 0xFF0000, 0xFFFF, 0xFFFF00,
                 0xFF00FF, 0xFFFFFF, 0x7F7F7F, 0x7F7F00, 0x7F007F, 0X7F7F};
    for (i = 0;i < 12;++i)
    {
        palette[i] = qpu_palette[i];
    }
*/
    if (!set_frame_buffer_palette(mb, palette))
    {
        fbd.memory_size = 0;
        printf("error: can't set palette\n");
        goto cleanup;
    }
    unsigned time = Microseconds();
    memset(fbd.arm_address, 0, fbd.memory_size);
    printf("time memset:%f\n", (Microseconds() - time) / 1000000.f);
    unsigned char *pfb = fbd.arm_address + fbd.pitch * 100;
    for (i = 0;i < 640;++i){
        pfb[i] = (unsigned char)i;
    }

    printf("frame buffer ok: %08x %08x\n", fbd.arm_address, fbd.gpu_address);


    //needed for vsync...
    int fbfd = open("/dev/fb0", O_RDWR);
    if (!fbfd)
    {
        printf("Error: cannot open framebuffer device.\n");
        goto cleanup;
    }
//end init frame buffer




    unsigned size = QPU_MEM_SIZE + QPU_DUMP_SIZE;
    unsigned align = 4096;
    unsigned handle = mem_alloc(mb, size, align, GPU_MEM_FLG);
    if (!handle)
    {
        printf("Failed to allocate GPU memory.");
        goto cleanup;
    }
    void *gpu_pointer = (void *)mem_lock(mb, handle);
    void *arm_pointer = mapmem((unsigned)gpu_pointer+GPU_MEM_MAP, size);
    unsigned gpu_dump_memory = ((unsigned) arm_pointer) + QPU_MEM_SIZE;

    int_to_float_to_int *dump_memory = (int_to_float_to_int *)(((unsigned char *)arm_pointer) + QPU_MEM_SIZE);
    memset(arm_pointer, 0x55, size);
    unsigned *qpu_code = (unsigned *)arm_pointer;
    memcpy(qpu_code, program, sizeof program);

    int_to_float_to_int *qpu_uniform = ((int_to_float_to_int *)arm_pointer) + (sizeof program)/(sizeof program[0]);
    unsigned int width =  fbd.width; //640;//
    unsigned int height = fbd.height;//400;//
#ifdef MANDELBROT            
    float xc = X_MANDEL;
    float yc = Y_MANDEL;
    float size_mandel = INITIAL_SIZE_MANDEL;
    float speed2 = 0.01f;
    float speed = 0.001f;
#endif

    float alpha = 0;
#ifdef JULIA
    float xc, yc;
    float speed2 = 0.1f;
    float speed = 0.01f;
#endif        
    for (n_frame = 0;n_frame < NB_FRAMES;n_frame++){
        unsigned pb = SwapFB(fbd, mb, n_frame & 1);
         ioctl(fbfd, FBIO_WAITFORVSYNC, 0);
        int_to_float_to_int *p = qpu_uniform;
        unsigned n_uniform = 0;
#ifdef MANDELBROT            
        unsigned nb_iter = (unsigned)sqrt(4.f/size_mandel) + 256;
#endif
#ifdef JULIA
        unsigned nb_iter = 256;
#endif        
        xc = X_MANDEL + cos(alpha) *  (NB_FRAMES - n_frame) * speed2 / NB_FRAMES;
        yc = Y_MANDEL + sin(alpha) * (NB_FRAMES - n_frame) * speed2 / NB_FRAMES;
        for (i = 0;i < GPU_QPUS;i++)
        {
            n_uniform = 0;
            p[n_uniform++].ui = GPU_QPUS;
            p[n_uniform++].ui = i;
            p[n_uniform++].ui = as_gpu_address(dump_memory);
            p[n_uniform++].ui = fbd.gpu_address;
            p[n_uniform++].ui = pb;
            p[n_uniform++].ui = fbd.pitch;
            p[n_uniform++].ui = width;
            p[n_uniform++].ui = height;
            p[n_uniform++].f = 1.f / width;
            p[n_uniform++].f = 1.f / height;
            
            //mandelbrot
#ifdef MANDELBROT            
            p[n_uniform++].f = xc;
            p[n_uniform++].f = yc;
            p[n_uniform++].f = size_mandel;
            p[n_uniform++].f = size_mandel;
#endif
#ifdef JULIA
            p[n_uniform++].f = xc;
            p[n_uniform++].f = yc;
#endif
            p[n_uniform++].ui = nb_iter;

            p += n_uniform;

        }



        unsigned *qpu_msg = (unsigned *)p;
        for (i = 0;i < GPU_QPUS;i++)
        {

            p[0].ui = as_gpu_address(qpu_uniform + i * n_uniform * sizeof(unsigned));
            p[1].ui = as_gpu_address(qpu_code);
            p += 2;
        }
        if (!qpu_enabled)
        {
            qpu_enabled = !qpu_enable(mb, 1);
        }
        if (!qpu_enabled)
        {
            printf("Unable to enable QPU. Check your firmware is latest.\n");
            goto cleanup;
        }

        time = Microseconds();
        unsigned r = execute_qpu(mb, GPU_QPUS, as_gpu_address(qpu_msg), 1, 1000);
        if (r == 0x80000000)
        {
    //sync pb?
            printf("QPU SYNC ERR???\n");
            qpu_enable(mb, 0);
            qpu_enabled = 0;
        }
        i = 0;
        while (i < QPU_DUMP_SIZE){
            int_to_float_to_int tmp;
            printf("%08X ", dump_memory[i>>2].ui);
            //printf("%f ", dump_memory[i>>2].f);
            i += 4;
            if ((i & 0x3F) == 0){
                printf("\n");
            }
        }
#ifdef MANDELBROT
        printf("nb iter : %i size : %f  time : %f\n\n", nb_iter, size_mandel, (Microseconds() - time) / 1000000.f);
        size_mandel *= 0.99f;
#endif
#ifdef JULIA
        printf("nb iter : %i  time : %f\n\n", nb_iter,  (Microseconds() - time) / 1000000.f);
        alpha += speed;
#endif
    }
    SwapFB(fbd, mb, n_frame & 1);
    printf("press enter...\n");
    scanf("%c", &i);
cleanup:
    i = 0;
    while (i < QPU_DUMP_SIZE){
        int_to_float_to_int tmp;
        printf("%08X ", dump_memory[i>>2].ui);
        //printf("%f ", dump_memory[i>>2].f);
        i += 4;
        if ((i & 0x3F) == 0){
            printf("\n");
        }
    }
    printf("\n\n");
    i = 0;
    n_frame = 0;
    /*while (n_frame < 20){
        printf("%x ", fbd.arm_address[i+n_frame*fbd.pitch]);
        i += 1;
        if ((i & 0xF) == 0){
            printf("\n\n");
            n_frame += 1;
            i = 0;
        }
    }*/

    
    printf("\n\n");
    if (qpu_enabled)
    {
        qpu_enable(mb, 0);
    }
    if (arm_pointer) {
        unmapmem(arm_pointer, size);
    }
    if (handle) {
        mem_unlock(mb, handle);
        mem_free(mb, handle);
    }

    if(fbd.memory_size != 0){
        release_frame_buffer(mb, &fbd);
    }

    if (kbfd >= 0) {
        ioctl(kbfd, KDSETMODE, KD_TEXT);
    }
    else {
        printf("Could not open %s.\n", kbfds);
    }
    close(kbfd);
    close(fbfd);
    mbox_close(mb);


    return 1;
}

