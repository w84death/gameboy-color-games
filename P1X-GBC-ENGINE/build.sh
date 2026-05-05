#!/bin/sh
rgbasm -o main.o SRC/main.asm
rgblink -o ROM/p1x_gbc_engine.gbc main.o && rm main.o
rgbfix -v -p 0 -C ROM/p1x_gbc_engine.gbc
