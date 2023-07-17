# ktrider (for CP/M)

Kevin Boone, July 2023

## What is this?

This is a rather silly and pointless program for CP/M that displays
a pattern on a set of 8 LEDs similar to that of the 'Knight Rider'
car of the 80s TV show (also known as the 'Cylon helmet' pattern). See
the included demo.mp4 to see the pattern.

Although it's a trivial application, the program is actually quite
complicated, because it uses pulse-width modulation (PWM) of the LEDs
to create smooth-looking transitions between patterns.

I wrote this to use with the front panel LEDs of an RC2014 system. 
Conventionally, these LEDs are at port zero. 

Because I couldn't be bothered to create a user interface for so silly a
program, the only way to change the output port or the speed of the 
animation is by editing and rebuilding. All the settings that can
usefully be edited are at the start of main.asm.

## Building

I wrote this utility to be built on CP/M using the Microsoft
Macro80 assembler and Link80 linker. These are available from here:

http://www.retroarchive.org/cpm/lang/m80.com
http://www.retroarchive.org/cpm/lang/l80.com

Assemble all the `.asm` files to produce `.rel` files, then feed all
the `.rel` files into the linker. See the Makefile (for Linux) for
the syntax for these commands. There is no `make` for CP/M, so far as I
know, so building on CP/M is a bit of a tedious process.

Building on Linux is easy, if you have an emulator that can be invoked
from the command line -- just run 'make'. See the `Makefile` for information
about a suitable emulator.

## Technical notes

The brightness of each LED is represented as a number between 0 and
255. These represent that fraction of the time that the LED is switched
on, in 255ths. So 255 is fully on, 0 fully off.

In practice, the perceived brightness is very non-linear. There's a big
difference between zero and ten, and then correspondingly less difference
thereafter. I've picked brightness values that looked nice with my 
specific front panel LEDs. I've tried with other LEDs, and the 
results are definitely not as satisfactory. 

## Limitations

Apart from the obvious limitation that it's a pointless waste of energy,
be aware that this program never quits. You'll need to reset the CPU. I found
that checking for keyboard activity made the display jumpy.

## Legal

For what it's worth, `ktrider` is copyright (c)2023 Kevin Boone, distributed
under the terms of the GNU Public Licence, v3.0. There is no warranty of
any kind.

