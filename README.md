# RISC-V-emulator-opensbi

OpenSBI build wrapper for the [RISC-V emulator](../RISC-V-emulator-Native). The wrapper pins OpenSBI at commit `ed70256dd22c09962d146e433834239825ef0616` in the shared cache and builds two `fw_jump` variants in a container: a minimal ISA build for the lean emulator and a full-ISA build for the maximal image.

## Layout

- `$XDG_CACHE_HOME/riscv-emulator/opensbi-ed70256dd22c09962d146e433834239825ef0616` - pinned OpenSBI source, outside both repositories.
- `configs/opensbi_defconfig` - Kconfig with the FDT drivers present in `linux-mmu.dts` and the SBI extensions used by Linux.
- `Makefile` - `fetch`, `build`, `build-max`, `clean`, `distclean` and `purge-cache` targets.
- `build-min/` and `build-max/` - out-of-tree build outputs (gitignored).

## Dependencies

The build image is `riscv-emulator-tools-container`. It provides the xPack `riscv-none-elf-gcc` bare-metal toolchain and `gcc-riscv64-linux-gnu`. OpenSBI links with `-pie`, so the build uses the Linux GCC via `CROSS_COMPILE=riscv64-linux-gnu-` with `PLATFORM_RISCV_XLEN=32` and `PLATFORM_RISCV_ABI=ilp32` to produce RV32 ILP32 images.

## Build

```sh
make fetch     # fetch the pinned OpenSBI commit into the cache
make build     # build-min: rv32ima_zicsr_zifencei
make build-max # build-max: full emulator ISA
```

The cached source is mounted into the container at `/opensbi-src` and this wrapper at `/src`. Both builds are out-of-tree (`O=/src/build-min` and `O=/src/build-max`), so the cached source stays clean. Override `XDG_CACHE_HOME` to move the cache. `make distclean` removes the build outputs; `make purge-cache` removes the cached source.

## Output

- `build-min/platform/generic/firmware/fw_jump.bin` - minimal image, loaded at `0x80000000`.
- `build-max/platform/generic/firmware/fw_jump.bin` - maximal image, loaded at `0x80000000`.

`FW_JUMP_OFFSET=0x400000` targets U-Boot at `0x80400000`; `FW_JUMP_FDT_OFFSET=0x2200000` targets the DTB at `0x82200000`. Both variants expose `base,ipi,time,srst` as standard SBI extensions and register the DTS syscon reset devices (`syscon-reboot`, `syscon-poweroff`).

## License

Apache-2.0. OpenSBI is BSD-2-Clause and keeps its own license in the cached source.
