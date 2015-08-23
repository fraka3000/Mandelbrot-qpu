# Mandelbrot-qpu
to assemble the qpuasm part, you need [vc4asm](https://github.com/maazl/vc4asm)
you need to create a char_dev file : `sudo mknod char_dev c 100 0` 
`make`
`./mandelbrot` or `./julia`

thanks to all guys who created contents/samples for the videocore IV/QPU ([Pete Warden](https://twitter.com/petewarden), [Andrew Holme](http://www.aholme.co.uk/), [Herman Hermitage](https://github.com/hermanhermitage/videocoreiv-qpu), [Raspberry Pi Playground](https://rpiplayground.wordpress.com), [Marcel Müller](http://maazl.de)...)
