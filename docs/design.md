# Design

## Upstream

OpenSBI is pinned at commit `ed70256dd22c09962d146e433834239825ef0616` (`v1.9-127-ged70256d`). The wrapper fetches that exact commit into the shared cache. The commit is fetched by SHA so the tested tree is reproduced exactly.

## ISA

The minimal variant builds with `rv32ima_zicsr_zifencei`. M and A are both required:

- M: `firmware/fw_base.S` uses `div` in the boot-hart wait loop, `include/sbi/riscv_barrier.h` uses `div` for `cpu_relax()`, and `lib/utils/libquad` implements 64-bit division. A build with `rv32ia_zicsr_zifencei` fails with `unrecognized opcode 'div', extension 'm' required`.
- A: `lib/sbi/riscv_locks.c` and `lib/sbi/riscv_atomic.c` use `lr.w`/`sc.w`/`amoswap.w` for locks and atomics.

The maximal variant uses the full emulator ISA from the Linux README. The SBI feature set is identical for both variants; the compiler ISA differs.

## SBI features

`configs/opensbi_defconfig` enables `SBI_ECALL_TIME` and `SBI_ECALL_IPI` on top of the generic platform's FDT drivers. The resulting firmware reports `base,ipi,time` as standard SBI extensions. The remaining extensions have no role in this kernel configuration:

- `RFENCE` and `HSM`: the kernel is UP (`CONFIG_SMP=n`).
- `SRST`: the DTS supplies `syscon-reboot` and `syscon-poweroff`.
- `LEGACY` and `DBCN`: the console is the 16550 `earlycon`.
- `PMU`, `CPPC`, `FWFT`, `VENDOR`, `DBTR`, `SSE`, `MPXY`, `SUSP`.

Both the minimal and maximal Linux images boot to login with this feature set.

## Firmware

`FW_JUMP` is used because the emulator loads OpenSBI, U-Boot and the DTB separately. `FW_JUMP_OFFSET=0x400000` makes OpenSBI jump to U-Boot at `0x80400000`; `FW_JUMP_FDT_OFFSET=0x2200000` places the DTB at `0x82200000`. These match the load addresses in the Linux and U-Boot repos.

## Container

The wrapper uses `riscv-emulator-tools-container` directly. OpenSBI requires PIE linking, so the tools container provides `gcc-riscv64-linux-gnu`. The build uses the Linux GCC with `PLATFORM_RISCV_XLEN=32` and `PLATFORM_RISCV_ABI=ilp32` to produce 32-bit ILP32 images.
