#
# american fuzzy lop - LLVM instrumentation (flip)
# ------------------------------------------------
# Added build profile menu for MAP_SIZE
#

#
#    Modifications for SACK
#    -------------------------------------

#    Modified by Zhechang Zhang, 2025.

#    These modifications remain under the original Apache 2.0 license
#    and retain all original copyright and attribution notices.
#

PREFIX       ?= /usr/local
HELPER_PATH   = $(PREFIX)/lib/afl
BIN_PATH      = $(PREFIX)/bin

VERSION      = $(shell grep '^\#define VERSION ' ../config.h | cut -d '"' -f2)

CC           = clang
CXX          = clang++
LLVM_CONFIG ?= llvm-config

# Default MAP_SIZE (can be overridden by menu or env)
MAP_SIZE    ?= 65536

CFLAGS      ?= -O3 -funroll-loops
CFLAGS      += -Wall -D_FORTIFY_SOURCE=2 -g -Wno-pointer-sign \
               "-DAFL_PATH=\"$(HELPER_PATH)\"" \
               "-DBIN_PATH=\"$(BIN_PATH)\"" \
               -DMAP_SIZE=$(MAP_SIZE)

ifdef AFL_TRACE_PC
  CFLAGS    += -DUSE_TRACE_PC=1
endif

CXXFLAGS    ?= -O3 -funroll-loops
CXXFLAGS    += -Wall -D_FORTIFY_SOURCE=2 -g -Wno-pointer-sign \
               -Wno-variadic-macros \
               -DMAP_SIZE=$(MAP_SIZE)

# Mark nodelete to work around unload bug in upstream LLVM 5.0+
CLANG_CFL    = `$(LLVM_CONFIG) --cxxflags` -Wl,-znodelete -fno-rtti -fpic -I/usr/include/jsoncpp $(CXXFLAGS)
CLANG_LFL    = `$(LLVM_CONFIG) --ldflags` $(LDFLAGS) -ljsoncpp

ifeq "$(shell uname)" "Darwin"
  CLANG_LFL += -Wl,-flat_namespace -Wl,-undefined,suppress
endif

ifeq "$(origin CC)" "default"
  CC         = clang
  CXX        = clang++
endif

ifndef AFL_TRACE_PC
  PROGS      = ../afl-clang-fast-indirect-flip ../afl-llvm-pass-indirect-flip.so ../afl-llvm-rt-indirect-flip.o ../afl-llvm-rt-indirect-flip-32.o ../afl-llvm-rt-indirect-flip-64.o
else
  PROGS      = ../afl-clang-fast-indirect-flip ../afl-llvm-rt-indirect-flip.o ../afl-llvm-rt-indirect-flip-32.o ../afl-llvm-rt-indirect-flip-64.o
endif

# Menu target (override MAP_SIZE var; do NOT append a new -DMAP_SIZE)
.PHONY: choose
choose:
	  $(MAKE) clean; \
	  $(MAKE) all MAP_SIZE=65536; \

all: test_deps $(PROGS) test_build all_done

test_deps:
ifndef AFL_TRACE_PC
	@echo "[*] Checking for working 'llvm-config'..."
	@which $(LLVM_CONFIG) >/dev/null 2>&1 || ( echo "[-] Oops, can't find 'llvm-config'. Install clang or set \$$LLVM_CONFIG or \$$PATH beforehand."; echo "    (Sometimes, the binary will be named llvm-config-3.5 or similar.)"; exit 1 )
else
	@echo "[!] Note: using -fsanitize=trace-pc mode (this may fail with older LLVM)."
endif
	@echo "[*] Checking for working '$(CC)'..."
	@which $(CC) >/dev/null 2>&1 || ( echo "[-] Oops, can't find '$(CC)'. Make sure that it's in your \$$PATH."; exit 1 )
	@echo "[*] Checking for '../afl-showmap'..."
	@test -f ../afl-showmap || ( echo "[-] Oops, can't find '../afl-showmap'. Be sure to compile AFL first."; exit 1 )
	@echo "[+] All set and ready to build."

../afl-clang-fast-indirect-flip: afl-clang-fast-indirect-flip.c | test_deps
	$(CC) $(CFLAGS) $< -o $@ $(LDFLAGS)
	ln -sf afl-clang-fast-indirect-flip ../afl-clang-fast-indirect-flip++

../afl-llvm-pass-indirect-flip.so: afl-llvm-pass-indirect-flip.so.cc | test_deps
	$(CXX) $(CLANG_CFL) -shared $< -o $@ $(CLANG_LFL)

../afl-llvm-rt-indirect-flip.o: afl-llvm-rt-indirect-flip.o.c | test_deps
	$(CC) $(CFLAGS) -fPIC -c $< -o $@

../afl-llvm-rt-indirect-flip-32.o: afl-llvm-rt-indirect-flip.o.c | test_deps
	@printf "[*] Building 32-bit runtime (-m32)... "
	@$(CC) $(CFLAGS) -m32 -fPIC -c $< -o $@ 2>/dev/null; if [ $$? -eq 0 ]; then echo "success!"; else echo "failed (that's fine)"; fi

../afl-llvm-rt-indirect-flip-64.o: afl-llvm-rt-indirect-flip.o.c | test_deps
	@printf "[*] Building 64-bit runtime (-m64)... "
	@$(CC) $(CFLAGS) -m64 -fPIC -c $< -o $@ 2>/dev/null; if [ $$? -eq 0 ]; then echo "success!"; else echo "failed (that's fine)"; fi

test_build: $(PROGS)
	@echo "[*] Testing the CC wrapper and instrumentation output..."
	unset AFL_USE_ASAN AFL_USE_MSAN AFL_INST_RATIO; AFL_QUIET=1 AFL_PATH=. AFL_CC=$(CC) ../afl-clang-fast-indirect-flip $(CFLAGS) ../test-instr.c -o test-instr $(LDFLAGS)
	@rm -f test-instr
	@echo "[+] Instrumentation test passed."

all_done: test_build
	@echo "[+] Build finished! You can now use '../afl-clang-fast-indirect-flip'."

.NOTPARALLEL: clean

clean:
	rm -f *.o *.so *~ a.out core core.[1-9][0-9]* test-instr .test-instr0 .test-instr1
	rm -f $(PROGS) ../afl-clang-fast-indirect-flip++