#!/bin/sh -v
clang -Wall -o divd divd.c
lwasm --list=divd_test.list -odivd_test.bin divd_test.asm
lwasm --list=divd_check.list -odivd_check.bin divd_check.asm
./divd b
decb copy -2b divd_test.bin divdt_b.dsk,TEST.BIN
decb copy -2b divd_check.bin divdt_b.dsk,CHECK.BIN
