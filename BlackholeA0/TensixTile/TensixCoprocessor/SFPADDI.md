# `SFPADDI` (Vectorised floating-point addition/subtraction using BF16 immediate)

**Summary:** Performs lanewise FP32 `VD = BF16ToFP32(Imm16) ± VD`.

**Backend execution unit:** [Vector Unit (SFPU)](VectorUnit.md), MAD sub-unit

## Syntax

```c
TT_SFPADDI(/* u16 */ Imm16, /* u4 */ VD, /* u4 */ Mod1)
```

## Encoding

![](../../../Diagrams/Out/Bits32_SFPADDI.svg)

## Functional model

```c
unsigned VC = VD;
lanewise {
  if (VD < 12 || LaneConfig[Lane].DISABLE_BACKDOOR_LOAD) {
    if (LaneEnabled) {
      float c = LReg[VC].f32;
      if (Mod1 & SFPMAD_MOD1_NEGATE_VC) c = -c;
      float d = BF16ToFP32(Imm16) * 1.0 + c;
      unsigned vd;
      if ((Mod1 & SFPMAD_MOD1_INDIRECT_VD) && VD != 16) {
        vd = LReg[7].u32 & 15;
      } else {
        vd = VD;
      }
      if (vd < 8 || vd == 16) {
        LReg[vd].f32 = d;
      }
    }
  }
}
```

Supporting definitions:

```c
#define SFPMAD_MOD1_NEGATE_VC 2
#define SFPMAD_MOD1_INDIRECT_VD 8

float BF16ToFP32(uint16_t x) {
  return std::bit_cast<float>(uint32_t(x) << 16);
}
```

## IEEE754 conformance / divergence

As per [`SFPMAD`](SFPMAD.md#ieee754-conformance--divergence).

## Instruction scheduling

As per [`SFPMAD`](SFPMAD.md#instruction-scheduling).
