# "Baby" RISCVs

Each Tensix tile contains five RISCV cores. Collectively, these are called "baby" cores as they are relatively small 32-bit in-order single-issue cores, optimised for area and power efficiency rather than for high performance. Each RISCV core is intended to execute one RISCV instruction per cycle, running at a clock speed of 1.35 GHz. The five cores are called RISCV B, RISCV T0, RISCV T1, RISCV T2, and RISCV NC.

## Instruction set

The full RV32IM instruction set is implemented, plus all of "Zicsr" / "Zaamo" / "Zba" / "Zbb", plus some (but not all) of "Zicntr" / `F` / "Zfh". RISCV T2 additionally implements some (but not all) of `V`. See [instruction set](InstructionSet.md) for details.

One entirely bespoke instruction set extension is implemented: [`.ttinsn`](PushTensixInstruction.md#ttinsn-instruction-set-extension).

## Memory map

The "NoC" column indicates which parts of the address space are made available to the NoC (and to the Tensix coprocessor) in addition to being available to RISCV cores.

<table><thead><tr><th>Name and address range</th><th>RISCV&nbsp;B</th><th>RISCV&nbsp;T0</th><th>RISCV&nbsp;T1</th><th>RISCV&nbsp;T2</th><th>RISCV&nbsp;NC</th><th>NoC</th></tr></thead>
<tr><td><code>MEM_L1_BASE</code><br/><code>0x0000_0000</code> to <code>0x0017_FFFF</code></td><td colspan="6"><a href="../L1.md">L1 scratchpad RAM (1536 KiB)</a></td></tr>
<tr><td><code>MEM_LOCAL_BASE</code><br/><code>0xFFB0_0000</code> to <code>0xFFB0_0FFF</code></td><td rowspan="2"><a href="README.md#local-data-ram">RISCV B local data RAM</a></td><td><a href="README.md#local-data-ram">RISCV T0 local data RAM</a></td><td><a href="README.md#local-data-ram">RISCV T1 local data RAM</a></td><td><a href="README.md#local-data-ram">RISCV T2 local data RAM</a></td><td rowspan="2"><a href="README.md#local-data-ram">RISCV NC local data RAM</a></td><td rowspan="2">Unmapped</td></tr>
<tr><td><code>0xFFB0_1000</code> to <code>0xFFB0_1FFF</code></td><td colspan="3">Unmapped</td></tr>
<tr><td><code>RISCV_TDMA_REGS_START_ADDR</code><br/><code>0xFFB1_1000</code> to <code>0xFFB1_1FFF</code></td><td colspan="4"><a href="../TDMA-RISC.md">TDMA-RISC configuration registers and command interface</a></td><td colspan="2">Unmapped</td></tr>
<tr><td><code>RISCV_DEBUG_REGS_START_ADDR</code><br/><code>0xFFB1_2000</code> to <code>0xFFB1_2FFF</code></td><td colspan="6"><a href="../TileControlDebugStatus.md">Tile control / debug / status registers</a></td></tr>
<tr><td><code>RISC_PIC_BASE</code><br/><code>0xFFB1_3000</code> to <code>0xFFB1_3137</code></td><td colspan="6"><a href="../PIC.md">PIC configuration and status registers</a></td></tr>
<tr><td><code>0xFFB1_3138</code> to <code>0xFFB1_314B</code></td><td colspan="6">RISCV <code>pc</code> snapshot</td></tr>
<tr><td><code>0xFFB1_4000</code> to <code>0xFFB1_5FFF</code></td><td colspan="6"><a href="README.md#local-data-ram">RISCV B local data RAM</a> (slow access path)</td></tr>
<tr><td><code>0xFFB1_6000</code> to <code>0xFFB1_7FFF</code></td><td colspan="6"><a href="README.md#local-data-ram">RISCV NC local data RAM</a> (slow access path)</td></tr>
<tr><td><code>0xFFB1_8000</code> to <code>0xFFB1_8FFF</code></td><td colspan="6"><a href="README.md#local-data-ram">RISCV T0 local data RAM</a> (slow access path)</td></tr>
<tr><td><code>0xFFB1_9000</code> to <code>0xFFB1_9FFF</code></td><td colspan="6"><a href="README.md#local-data-ram">RISCV T0 local data RAM</a> (slow access path)</td></tr>
<tr><td><code>0xFFB1_A000</code> to <code>0xFFB1_AFFF</code></td><td colspan="6"><a href="README.md#local-data-ram">RISCV T1 local data RAM</a> (slow access path)</td></tr>
<tr><td><code>0xFFB1_B000</code> to <code>0xFFB1_BFFF</code></td><td colspan="6"><a href="README.md#local-data-ram">RISCV T1 local data RAM</a> (slow access path)</td></tr>
<tr><td><code>0xFFB1_C000</code> to <code>0xFFB1_CFFF</code></td><td colspan="6"><a href="README.md#local-data-ram">RISCV T2 local data RAM</a> (slow access path)</td></tr>
<tr><td><code>0xFFB1_D000</code> to <code>0xFFB1_DFFF</code></td><td colspan="6"><a href="README.md#local-data-ram">RISCV T2 local data RAM</a> (slow access path)</td></tr>
<tr><td><code>NOC0_REGS_START_ADDR</code><br/><code>0xFFB2_0000</code> to <code>0xFFB2_FFFF</code></td><td colspan="6"><a href="../../NoC/MemoryMap.md">NoC 0 configuration registers and command interface</a></td></tr>
<tr><td><code>NOC1_REGS_START_ADDR</code><br/><code>0xFFB3_0000</code> to <code>0xFFB3_FFFF</code></td><td colspan="6"><a href="../../NoC/MemoryMap.md">NoC 1 configuration registers and command interface</a></td></tr>
<tr><td><code>NOC_OVERLAY_START_ADDR</code><br/><code>0xFFB4_0000</code> to <code>0xFFB7_FFFF</code></td><td colspan="6"><a href="../../NoC/Overlay/README.md">NoC overlay configuration registers and command interface</a></td></tr>
<tr><td><code>TENSIX_MOP_CFG_BASE</code><br/><code>0xFFB8_0000</code> to <code>0xFFB8_0023</code></td><td>Unmapped</td><td><a href="../TensixCoprocessor/MOPExpander.md#configuration">T0 MOP expander configuration</a></td><td><a href="../TensixCoprocessor/MOPExpander.md#configuration">T1 MOP expander configuration</a></td><td><a href="../TensixCoprocessor/MOPExpander.md#configuration">T2 MOP expander configuration</a></td><td colspan="2">Unmapped</td></tr>
<tr><td><code>0xFFBD_8000</code> to <code>0xFFBD_FFFF</code></td><td>Unmapped</td><td colspan="3">Tensix <code>Dst</code></td><td colspan="2">Unmapped</td></tr>
<tr><td><code>REGFILE_BASE</code><br/><code>0xFFE0_0000</code> to <code>0xFFE0_0FFF</code></td><td><a href="../TensixCoprocessor/ScalarUnit.md#gprs">Tensix T0/T1/T2 GPRs</a></td><td><a href="../TensixCoprocessor/ScalarUnit.md#gprs">Tensix T0 GPRs</a></td><td><a href="../TensixCoprocessor/ScalarUnit.md#gprs">Tensix T1 GPRs</a></td><td><a href="../TensixCoprocessor/ScalarUnit.md#gprs">Tensix T2 GPRs</a></td><td colspan="2">Unmapped</td></tr>
<tr><td><code>INSTRN_BUF_BASE</code><br/><code>0xFFE4_0000</code> to <code>0xFFE4_FFFF</code></td><td><a href="PushTensixInstruction.md">Push Tensix T0 instruction</a>, after T0 MOP expander</td><td><a href="PushTensixInstruction.md">Push Tensix T0 instruction</a>, before T0 MOP expander</td><td><a href="PushTensixInstruction.md">Push Tensix T1 instruction</a>, before T1 MOP expander</td><td><a href="PushTensixInstruction.md">Push Tensix T2 instruction</a>, before T2 MOP expander</td><td colspan="2">Unmapped</td></tr>
<tr><td><code>INSTRN1_BUF_BASE</code><br/><code>0xFFE5_0000</code> to <code>0xFFE5_FFFF</code></td><td><a href="PushTensixInstruction.md">Push Tensix T1 instruction</a>, after T1 MOP expander</td><td colspan="5">Unmapped</td></tr>
<tr><td><code>INSTRN2_BUF_BASE</code><br/><code>0xFFE6_0000</code> to <code>0xFFE6_FFFF</code></td><td><a href="PushTensixInstruction.md">Push Tensix T2 instruction</a>, after T2 MOP expander</td><td colspan="5">Unmapped</td></tr>
<tr><td><code>PC_BUF_BASE</code><br/><code>0xFFE8_0000</code> to <code>0xFFE8_0003</code></td><td rowspan="3"><a href="PCBufs.md">PCBuf</a> from B to T0, B side</td><td><a href="PCBufs.md">PCBuf</a> from B to T0, T side</td><td><a href="PCBufs.md">PCBuf</a> from B to T1, T side</td><td><a href="PCBufs.md">PCBuf</a> from B to T2, T side</td><td colspan="2" rowspan="3">Unmapped</td></tr>
<tr><td><code>0xFFE8_0004</code> to <code>0xFFE8_001F</code></td><td><a href="TTSync.md">TTSync T0</a></td><td><a href="TTSync.md">TTSync T1</a></td><td><a href="TTSync.md">TTSync T2</a></td></tr>
<tr><td><code>0xFFE8_0020</code> to <code>0xFFE8_FFFF</code></td><td colspan="3"><a href="../TensixCoprocessor/SyncUnit.md#semaphores">Tensix semaphores</a></td></tr>
<tr><td><code>PC1_BUF_BASE</code><br/><code>0xFFE9_0000</code> to <code>0xFFE9_FFFF</code></td><td><a href="PCBufs.md">PCBuf</a> from B to T1, B side</td><td colspan="5">Unmapped</td></tr>
<tr><td><code>PC2_BUF_BASE</code><br/><code>0xFFEA_0000</code> to <code>0xFFEA_FFFF</code></td><td><a href="PCBufs.md">PCBuf</a> from B to T2, B side</td><td colspan="5">Unmapped</td></tr>
<tr><td><code>TENSIX_MAILBOX0_BASE</code><br/><code>0xFFEC_0000</code> to <code>0xFFEC_0FFF</code></td><td colspan="4" rowspan="4"><a href="Mailboxes.md">Mailboxes between pairs of RISCV cores</a></td><td colspan="2" rowspan="4">Unmapped</td></tr>
<tr><td><code>TENSIX_MAILBOX1_BASE</code><br/><code>0xFFEC_1000</code> to <code>0xFFEC_1FFF</code></td></tr>
<tr><td><code>TENSIX_MAILBOX2_BASE</code><br/><code>0xFFEC_2000</code> to <code>0xFFEC_2FFF</code></td></tr>
<tr><td><code>TENSIX_MAILBOX3_BASE</code><br/><code>0xFFEC_3000</code> to <code>0xFFEC_3FFF</code></td></tr>
<tr><td><code>TENSIX_CFG_BASE</code><br/><code>0xFFEF_0000</code> to <code>0xFFEF_FFFF</code></td><td colspan="4"><a href="../TensixCoprocessor/BackendConfiguration.md">Tensix backend configuration</a></td><td colspan="2">Unmapped</td></tr>
</table>

## Local data RAM

Each baby RISCV has either 8 KiB (B, NC) or 4 KiB (T0, T1, T2) of local data RAM. Each of these RAMs is present in the address space at two locations:
* At `MEM_LOCAL_BASE`, which is only accessible using load or store instructions from the one RISCV associated with it. Access to the RAM through this address is low latency, and never suffers from contention. A load from local RAM through this address has a latency of two cycles, meaning that so long as the one instruction immediately after the load is independent of the load result, the latency of the load is entirely hidden.
* At some address between `0xFFB1_4000` and `0xFFB1_DFFF`, which is accessible from any RISCV and accessible over the NoC. Access to the RAM through this address is higher latency, and does suffer from contention. A load from local RAM through this address has a latency of at least seven cycles (which is the same latency as loading from L1), meaning that six independent instructions are required to fully hide the latency.

Software is _strongly_ encouraged to place the call stack in this RAM, along with any thread-local variables and any frequently-used read-only global variables, and access it through the `MEM_LOCAL_BASE` address.

When the RISCV comes out of reset, the local data RAM will spend up to 2048 clock cycles resetting its contents to zero. If a RISCV core tries to access the RAM during this time, the core will be automatically stalled. However, the same is _not_ true for accesses coming over the NoC: software needs to ensure that any such accesses are not performed in the 2048 clock cycles after taking the RISCV out of reset.

For the purpose of RISCV memory ordering, each distinct mapping of the local data RAM into the address space is considered to be a separate memory region. As such, software is strongly encouraged to always use the `MEM_LOCAL_BASE` address for the RISCV core's own local data RAM, and only use the address between `0xFFB1_4000` and `0xFFB1_DFFF` for accessing the local data RAM of other RISCV cores.

> [!TIP]
> The Blackhole local data RAMs are twice the size of the Wormhole local data RAMs. The 2<sup>nd</sup> mapping between `0xFFB1_4000` and `0xFFB1_DFFF` is also new in Blackhole; it should enable the host to more easily initialise the local data RAM, and allow debuggers to more easily inspect it.
