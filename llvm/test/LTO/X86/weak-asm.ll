; Check that non-prevailing symbols in module inline assembly are discarded
; during regular LTO otherwise the final symbol binding could be wrong.

; RUN: split-file %s %t
; RUN: opt %t/t1.ll -o %t1
; RUN: opt %t/t2.ll -o %t2
; RUN: opt %t/t3.ll -o %t3

; RUN: llvm-lto2 run -o %to1 -save-temps %t1 %t2 \
; RUN:  -r %t1,foo,px \
; RUN:  -r %t2,foo, \
; RUN:  -r %t2,bar,pl
; RUN: llvm-dis < %to1.0.0.preopt.bc -o - | FileCheck %s --check-prefix=ASM
; RUN: llvm-nm %to1.0 | FileCheck %s --check-prefix=SYM
; RUN: llvm-objdump -d --disassemble-symbols=foo %to1.0 \
; RUN:   | FileCheck %s --check-prefix=DEF

; RUN: llvm-lto2 run -o %to2 -save-temps %t2 %t3 \
; RUN:  -r %t2,foo, \
; RUN:  -r %t2,bar,pl \
; RUN:  -r %t3,foo,px
; RUN: llvm-dis < %to2.0.0.preopt.bc -o - | FileCheck %s --check-prefix=ASM
; RUN: llvm-nm %to2.0 | FileCheck %s --check-prefix=SYM
; RUN: llvm-objdump -d --disassemble-symbols=foo %to2.0 \
; RUN:   | FileCheck %s --check-prefix=DEF

; ASM: module asm "{{[[:blank:]]*}}"

; SYM: T foo

; DEF: leal    2(%rdi), %eax

;--- t1.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define dso_local i32 @foo(i32 %0) {
  %2 = add nsw i32 %0, 2
  ret i32 %2
}

;--- t2.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

module asm ".weak foo"
module asm "\09 .equ foo,bar"

@llvm.compiler.used = appending global [1 x i8*] [i8* bitcast (i32 (i32)* @bar to i8*)], section "llvm.metadata"

define internal i32 @bar(i32 %0) {
  %2 = add nsw i32 %0, 1
  ret i32 %2
}

;--- t3.ll
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

module asm " .global foo ; foo: leal    2(%rdi), %eax"
