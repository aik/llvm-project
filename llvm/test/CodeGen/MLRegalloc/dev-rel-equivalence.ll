; REQUIRES: have_tf_api
; REQUIRES: have_tf_aot
; REQUIRES: llvm_raevict_model_autogenerated
; REQUIRES: x86_64-linux
;
; Check that the same model (==the autogenerated one) produces the same output
; regardless of how it's evaluated, which is different from the default
;
; RUN: llc -mtriple=x86_64-linux-unknown -regalloc=greedy -regalloc-enable-advisor=default \
; RUN:   %S/Inputs/input.ll -o %t.default

; RUN: llc -mtriple=x86_64-linux-unknown -regalloc=greedy -regalloc-enable-advisor=release \
; RUN:   %S/Inputs/input.ll -o %t.release

; RUN: rm -rf %t && mkdir %t
; RUN: %python %S/../../../lib/Analysis/models/gen-regalloc-eviction-test-model.py %t
; RUN: llc -mtriple=x86_64-linux-unknown -regalloc=greedy -regalloc-enable-advisor=development \
; RUN:   -regalloc-model=%t %S/Inputs/input.ll -o %t.development
; RUN: diff %t.release %t.development
; RUN: not diff %t.release %t.default
