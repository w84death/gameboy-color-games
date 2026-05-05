#!/bin/sh
rgbasm -o main.o SRC/main.asm
rgblink -o ROM/hello.gbc main.o && rm main.o
rgbfix -v -p 0 -C ROM/hello.gbc
