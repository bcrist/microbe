# Microbe

Microbe is a framework for developing embedded firmware in Zig, primarily targeting small 32-bit architectures like ARM Cortex-M0.  It is similar in many ways to [microzig](https://github.com/ZigEmbeddedGroup/microzig) and in fact some parts were forked directly from that project.  But there are a few things about microzig that I didn't like:

* Microzig caters heavily to the use of development boards, which is great for beginners, but just adds a lot of unnecessary complexity if you're using a microcontroller directly on your project/product board.
* Microzig has a HAL (hardware abstraction layer) concept that doesn't make sense to me.  The entire project is a hardware abstraction layer, so why is there a HAL within the HAL?
* The use of anonymous types to represent pins is weird, and seems to end up being a rather leaky abstraction.
* The UART interface doesn't provide any way to guarantee that calls won't block, and makes it difficult to implement a driver that buffers data and uses interrupts or DMA.
* There's no facility to easily work with multiple GPIOs simultaneously as a parallel bus.
* The SVD-generated register types can be difficult to use, especially where a field would ideally be represented by an enum.

Some of these issues could be solved by PRs to microzig but in some cases it's just a matter of stylistic differences of opinion.  If you're a microzig contributor and think something you see here should be ported, let me know and I'll see if I can help.

## Device Support

I plan to add new chips only as I use them in projects, so for now, the only supported architectures are:

* RP2040
* STM32G030x


