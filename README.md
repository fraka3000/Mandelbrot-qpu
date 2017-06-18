# Mandelbrot-qpu

to assemble the qasm files, you need [vc4asm](https://github.com/maazl/vc4asm) 

you need to create a device file : `sudo mknod char_dev c 249 0`.

`make`,

`sudo ./mandelbrot` or `sudo ./julia`

thanks to all guys who created contents/samples for the videocore IV/QPU ([Pete Warden](https://twitter.com/petewarden), [Andrew Holme](http://www.aholme.co.uk/), [Herman Hermitage](https://github.com/hermanhermitage/videocoreiv-qpu), [Raspberry Pi Playground](https://rpiplayground.wordpress.com), [Marcel Müller](http://maazl.de)...)
