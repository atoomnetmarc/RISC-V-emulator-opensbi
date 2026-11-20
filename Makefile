# OpenSBI build wrapper. The tools container is the build environment; the
# pinned source lives in the shared cache outside both repositories.

IMAGE          ?= riscv-emulator-tools-container:latest
OPENSBI_COMMIT ?= ed70256dd22c09962d146e433834239825ef0616
XDG_CACHE_HOME ?= $(HOME)/.cache
CACHE          := $(XDG_CACHE_HOME)/riscv-emulator
OPENSBI_SRC    := $(CACHE)/opensbi-$(OPENSBI_COMMIT)
CROSS_COMPILE  ?= riscv64-linux-gnu-
JOBS           ?= $(shell nproc)

SRC         := /src
OPENSBI_MNT := /opensbi-src
BUILD_MIN   := $(SRC)/build-min
BUILD_MAX   := $(SRC)/build-max

DOCKER ?= podman
RUN    := $(DOCKER) run --rm -v $(CURDIR):$(SRC) -v $(OPENSBI_SRC):$(OPENSBI_MNT) -w $(SRC)

# The minimal image uses I, M, A, Zicsr and Zifencei. M serves the div
# instructions in firmware/fw_base.S and riscv_barrier.h; A serves the hart
# lottery and the locks in riscv_locks.c.
ISA_MIN := rv32ima_zicsr_zifencei

# The maximal image uses the full emulator ISA from the Linux README. The SBI
# feature set is the same for both variants; the ISA differs.
ISA_MAX := rv32imac_zicsr_zifencei_zicntr_zicond_zihintntl_zihintpause_zimop_zca_zcb_zcmop_zba_zbb_zbkb_zbkc_zbkx_zbs

# FW_JUMP_OFFSET=0x400000 targets U-Boot at 0x80400000.
# FW_JUMP_FDT_OFFSET=0x2200000 targets the DTB at 0x82200000.
# PLATFORM_DEFCONFIG is relative to platform/generic/configs/ in the source.
OPENSBI_ARGS = PLATFORM=generic CROSS_COMPILE=$(CROSS_COMPILE) \
	PLATFORM_RISCV_XLEN=32 PLATFORM_RISCV_ABI=ilp32 \
	FW_JUMP=y FW_JUMP_OFFSET=0x400000 FW_JUMP_FDT_OFFSET=0x2200000 \
	PLATFORM_DEFCONFIG=../../../../src/configs/opensbi_defconfig

.PHONY: all fetch build build-min build-max clean distclean purge-cache

all: build build-max

$(OPENSBI_SRC)/Makefile:
	mkdir -p $(CACHE)
	rm -rf $(OPENSBI_SRC)
	git init -q $(OPENSBI_SRC)
	git -C $(OPENSBI_SRC) remote add origin https://github.com/riscv-software-src/opensbi.git
	git -C $(OPENSBI_SRC) fetch --depth 1 origin $(OPENSBI_COMMIT)
	git -C $(OPENSBI_SRC) checkout -q FETCH_HEAD

fetch: $(OPENSBI_SRC)/Makefile

build: fetch
	$(RUN) $(IMAGE) make -C $(OPENSBI_MNT) O=$(BUILD_MIN) $(OPENSBI_ARGS) \
		PLATFORM_RISCV_ISA=$(ISA_MIN) -j$(JOBS)

build-max: fetch
	$(RUN) $(IMAGE) make -C $(OPENSBI_MNT) O=$(BUILD_MAX) $(OPENSBI_ARGS) \
		PLATFORM_RISCV_ISA=$(ISA_MAX) -j$(JOBS)

clean:
	rm -rf build-min build-max

distclean: clean

purge-cache:
	rm -rf $(OPENSBI_SRC)
