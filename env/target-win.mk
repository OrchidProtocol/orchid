# Cycc/Cympile - Shared Build Scripts for Make
# Copyright (C) 2013-2019  Jay Freeman (saurik)

# Zero Clause BSD license {{{
#
# Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
# }}}


pre := 
dll := dll
lib := lib
exe := .exe

meson := windows

archs += i686
openssl/i686 := mingw
host/i686 := i686-w64-mingw32
triple/i686 := i686-pc-windows-gnu
meson/i686 := x86
bits/i686 := 32

archs += x86_64
openssl/x86_64 := mingw64
host/x86_64 := x86_64-w64-mingw32
triple/x86_64 := x86_64-pc-windows-gnu
meson/x86_64 := x86_64
bits/x86_64 := 64

include $(pwd)/target-gnu.mk

define _
more/$(1) := -target $(1)-pc-windows-gnu 
more/$(1) += --sysroot $(CURDIR)/$(output)/$(1)/mingw$(bits/$(1))
temp := $(shell which $(1)-w64-mingw32-ld)
ifeq ($$(temp),)
$$(error $(1)-w64-mingw32-ld must be on your path)
endif
more/$(1) += -B$$(dir $$(temp))$(1)-w64-mingw32-
endef
$(each)

more := -D_WIN32_WINNT=0x0601
include $(pwd)/target-ndk.mk
include $(pwd)/target-cxx.mk

source += $(pwd)/libcxx/src/support/win32/locale_win32.cpp
source += $(pwd)/libcxx/src/support/win32/support.cpp
cflags += -D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS
lflags += -nostdlib++ -lsupc++

define _
ranlib/$(1) := $(1)-w64-mingw32-ranlib
ar/$(1) := $(1)-w64-mingw32-ar
strip/$(1) := $(1)-w64-mingw32-ar
windres/$(1) := $(1)-w64-mingw32-windres
export CARGO_TARGET_$(subst -,_,$(call uc,$(triple/$(1))))_LINKER := true
# XXX: this should be $(shell realpath $(shell which $(1)-w64-mingw32-gcc))
# however, I'm blocked on https://github.com/rust-lang/rust/issues/68887
# XXX: also, Rust does not correctly link on 32-bit Windows due to this :(
# essentially same issue: https://github.com/rust-lang/rust/issues/12859
endef
$(each)

lflags += -static
lflags += -pthread
lflags += -lssp

wflags += -fuse-ld=ld
lflags += -Wl,--no-insert-timestamp

#cflags += -DNOMINMAX
cflags += -DWIN32_LEAN_AND_MEAN=
cflags += -D_CRT_RAND_S=

cflags += -fms-extensions
#cflags += -fms-compatibility
#cflags += -D__GNUC__

#  warning: 'I64' length modifier is not supported by ISO C
qflags += -Wno-format-non-iso

mflags += has_function_stpcpy=false

# pragma comment(lib, "...lib")
# pragma warning(disable : ...)
cflags += -Wno-pragma-pack
cflags += -Wno-unknown-pragmas

cflags += -Wno-unused-const-variable

qflags += -I$(CURDIR)/$(pwd)/win32
qflags += -Wno-nonportable-include-path

cflags += -I$(pwd)/mingw

msys2 := 
msys2 += crt-git-7.0.0.5553.e922460c-1
msys2 += dlfcn-1.2.0-1
msys2 += gcc-9.3.0-2
msys2 += headers-git-7.0.0.5553.e922460c-1
msys2 += winpthreads-git-7.0.0.5544.15da3ce2-1

define _
$(output)/$(1)/%.msys2:
	@mkdir -p $$(dir $$@)
	curl http://repo.msys2.org/mingw/$(1)/mingw-w64-$(1)-$$*-any.pkg.tar.xz | tar -C $(output)/$(1) -Jxvf-
	@touch $$@

sysroot += $(patsubst %,$(output)/$(1)/%.msys2,$(msys2))
endef
$(each)

default := x86_64
