# `SFPSTOCHRND` (Vectorised reduce floating-point precision)

**Summary:** Operating lanewise, reduces mantissa precision of an FP32 value down from 23 bits to either 7 bits or 10 bits. The discarded mantissa bits are used for rounding, which can be:
* Stochastic rounding (†).
* Round to nearest with ties away from zero.
* Round to zero (†).

Various extreme floating-point values are also normalised away:
* Denormals become positive zero.
* Negative zero becomes positive zero.
* -NaN becomes negative infinity.
* +NaN becomes positive infinity.

This flavour of `SFPSTOCHRND` is intended to be used prior to an [`SFPSTORE`](SFPSTORE.md) instruction:
* `SFPSTORE` with `MOD0_FMT_BF16`: If the mantissa precision is reduced to 7 bits, a store with `MOD0_FMT_BF16` will be exact.
* `SFPSTORE` with `MOD0_FMT_FP16`: If the mantissa precision is reduced to either 7 or 10 bits, a store with `MOD0_FMT_FP16` will suffer no loss of mantissa precision (though there will be loss of exponent range, with out of range values clamped to positive or negative infinity).
* `SFPSTORE` with `MOD0_FMT_FP32`: If the mantissa precision is reduced to either 7 or 10 bits, a store with `MOD0_FMT_FP32` will be exact, and any subsequent conversion to TF32 will also be exact.

> (†) Due to a hardware bug, stochastic rounding has a slight bias towards increasing the magnitude rather than being 50:50, and can even sometimes increase the magnitude of values which do not require rounding. Due to another hardware bug, rounding toward zero sometimes incorrectly rounds away from zero. The functional model faithfully describes all the buggy behaviours; the corrected logic would have `>` instead of `>=` when comparing `DiscardedBits` and `PRNGBits` (and thus also initialise `PRNGBits` with `0x3fffff` rather than `0x400000` for the `SFPSTOCHRND_RND_NEAREST` case).

**Backend execution unit:** [Vector Unit (SFPU)](VectorUnit.md), round sub-unit

> [!TIP]
> The round to zero mode is new in Blackhole, though a hardware bug means it sometimes incorrectly rounds away from zero. 

## Syntax

```c
TT_SFP_STOCH_RND(/* u2 */ RoundingMode, 0, /* u4 */ VC,
                 /* u4 */ VC, /* u4 */ VD, /* u3 */ Mod1)
```

> [!NOTE]
> `VC` is specified twice in the syntax to work around a false dependency bug in the automatic stalling logic of some other instructions. If instead looking at the encoding diagram (below), the mitigation is to set `VB` equal to `VC`.

## Encoding

![](../../../Diagrams/Out/Bits32_SFPSTOCHRND_BH.svg)

## Functional model

```c
if (Mod1 != SFPSTOCHRND_MOD1_FP32_TO_FP16A
 && Mod1 != SFPSTOCHRND_MOD1_FP32_TO_FP16B) {
  // Is some other flavour of SFPSTOCHRND; see other pages for details.
  UndefinedBehaviour();
}

lanewise {
  if (VD < 12 || LaneConfig.DISABLE_BACKDOOR_LOAD) {
    if (LaneEnabled) {
      uint32_t PRNGBits = AdvancePRNG() & 0x7fffff; // 23 bits
      switch (RoundingMode) {
      case SFPSTOCHRND_RND_NEAREST: PRNGBits = 0x400000; break;
      case SFPSTOCHRND_RND_ZERO:    PRNGBits = 0x7fffff; break;
      }
      uint32_t x = LReg[VC].u32; // FP32.
      uint32_t Exp = (x >> 23) & 0xff;
      if (Exp == 0) {
        // Denormal or zero? Becomes zero.
        x = 0;
      } else if (Exp == 255) {
        // +Infinity or +NaN? Becomes +Infinity.
        // -Infinity or -NaN? Becomes -Infinity.
        x &= 0xff800000u;
      } else if (Mod1 == SFPSTOCHRND_MOD1_FP32_TO_FP16A) {
        // Keep 10 bits of mantissa precision, discard 13 bits (use them for rounding).
        uint32_t DiscardedBits = x & 0x1fff;
        x -= DiscardedBits;
        if (DiscardedBits >= (PRNGBits >> 10)) x += 0x2000;
      } else /* Mod1 == SFPSTOCHRND_MOD1_FP32_TO_FP16B */ {
        // Keep 7 bits of mantissa precision, discard 16 bits (use them for rounding).
        uint32_t DiscardedBits = x & 0xffff;
        x -= DiscardedBits;
        if (DiscardedBits >= (PRNGBits >> 7)) x += 0x10000;
      }
      if (VD < 8 || VD == 16) {
        LReg[VD].u32 = x; // FP32.
      }
    }
  }
}
```

Supporting definitions:
```c
#define SFPSTOCHRND_MOD1_FP32_TO_FP16A  0
#define SFPSTOCHRND_MOD1_FP32_TO_FP16B  1

#define SFPSTOCHRND_RND_NEAREST 0
#define SFPSTOCHRND_RND_STOCH 1
#define SFPSTOCHRND_RND_ZERO 2
```
