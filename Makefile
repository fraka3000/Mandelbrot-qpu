
all: mandelbrot julia
mandelbrot.hex: mandelbrot.qasm
	vc4asm -V -C $@ vc4.qinc $<
julia.hex: julia.qasm
	vc4asm -V -C $@ vc4.qinc $<
	
mandelbrot: mailbox.c mandelbrot.c mandelbrot.hex 
	gcc -o  mandelbrot -DMANDELBROT mailbox.c mandelbrot.c -lrt -lm 
julia: mailbox.c mandelbrot.c julia.hex
	gcc -o  julia -DJULIA  mailbox.c mandelbrot.c -lrt -lm 
clean:
	rm -f mandelbrot julia mandelbrot.hex julia.hex



