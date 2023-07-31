# Microbe

Microbe is a framework for developing embedded firmware in Zig, primarily targeting small 32-bit architectures like ARM Cortex-M0.  It is similar in many ways to [microzig](https://github.com/ZigEmbeddedGroup/microzig) and in fact some parts were forked directly from that project.  But there are a few things about microzig that I didn't like:

* Microzig caters heavily to the use of development boards, which is great for beginners, but just adds a lot of unnecessary complexity if you're using a microcontroller directly on your project/product board.
* It forces a complex project structure on you.  You can't define the root source file yourself, instead it only exists in an "app" module.  There's a HAL (hardware abstraction layer) module that doesn't make sense; the entire project is a hardware abstraction layer, so why is there a HAL within the HAL?
* The use of anonymous types to represent pins is weird.  It seems the only reason is to ensure they're used at comptime, but you can do that just as easily with an enum passed as a `comptime` parameter.  The conflation of chip pins names and board pin names is annoying.
* The UART interface doesn't provide a non-blocking interface, or an easy way to support buffered implementations using interrupts or DMA.
* There's no facility to easily work with multiple GPIOs simultaneously as a parallel bus.
* The SVD-generated register types can be difficult to use, especially where a field would ideally be represented by an enum.

Some of these issues could be solved by PRs to microzig but in some cases it's just a matter of stylistic differences of opinion.  If you're a microzig contributor and think something you see here should be ported, let me know and I'll see if I can help.

## Project Structure & Device Support

This repository contains only the build-time code to set up a Microbe build.  Your project will get runtime code for your selected device through the Zig package manager, by depending on one of these repos:
* [microbe-stm32](https://github.com/bcrist/microbe-stm32) - STM32
* [microbe-rpi](https://github.com/bcrist/microbe-rpi) - RP2040

Device-independent runtime code lives in the [microbe-rt](https://github.com/bcrist/microbe-rt) repo, but you shouldn't need to add that to your `build.zig.zon` manually; you'll get it transitively through one of the above repos and it will be available in your main module via `@import("microbe")`.

## Building

It's recommended to include this repo in your project as a submodule since the Zig package manager doesn't currently provide a good way for package build scripts to interact with the parent build script.

You can see an example of how to set up a Microbe build in this repo's build.zig and build.zig.zon.  Just change the `const microbe = @import("microbe.zig")` line to point to wherever  `microbe.zig` in your repo.
