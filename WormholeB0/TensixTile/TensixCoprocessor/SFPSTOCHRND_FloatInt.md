# `SFPSTOCHRND` (Vectorised convert floating-point to bounded sign-magnitude integer)

**Summary:** Operating lanewise, starts with FP32, rounds that to an integer (can be either stochastic or round to nearest with ties away from zero), then does one of:
* Clamp to -127 through +127.
* Clamp to -32767 through +32767.
* Take absolute value, then clamp to 0 through 255.
* Take absolute value, then clamp to 0 through 65535.

The result is a 32-bit sign-magnitude integer, though if the absolute value was taken, the result can be interpreted as any kind of integer. This flavour of `SFPSTOCHRND` is intended to be used prior to certain modes of an [`SFPSTORE`](SFPSTORE.md) instruction:

|`SFPSTOCHRND` Mode|Resultant range|Matching `SFPSTORE` Mode|
|---|---|---|
|`SFPSTOCHRND_MOD1_FP32_TO_INT8`|±127|`MOD0_FMT_INT8`|
|`SFPSTOCHRND_MOD1_FP32_TO_UINT8`|0 - 255|`MOD0_FMT_INT8` or `MOD0_FMT_INT8_COMP`|
|`SFPSTOCHRND_MOD1_FP32_TO_INT16`|±32767|`MOD0_FMT_INT16`|
|`SFPSTOCHRND_MOD1_FP32_TO_UINT16`|0 - 65535|`MOD0_FMT_UINT16` or `MOD0_FMT_LO16_ONLY`|

Due to a hardware bug, inputs in range `|x| < 0.5` are always rounded deterministically (and thus to zero), even when stochastic rounding is requested. Due to a hardware bug, stochastic rounding of inputs in range `|x| ≥ 0.5` has a slight bias towards increasing the magnitude rather than being 50:50, and can even sometimes increase the magnitude of values which do not require rounding.

**Backend execution unit:** [Vector Unit (SFPU)](VectorUnit.md), round sub-unit

## Syntax

```c
TT_SFP_STOCH_RND(/* bool */ StochasticRounding,
                 0, 0,
                 /* u4 */ VC, /* u4 */ VD, /* u3 */ Mod1)
```

## Encoding

![](../../../Diagrams/Out/Bits32_SFPSTOCHRND.svg)

## Functional model

```c
bool KeepSign;
uint32_t MaxMagnitude;
switch (Mod1) {
case SFPSTOCHRND_MOD1_FP32_TO_INT8  : KeepSign = true ; MaxMagnitude =   127; break;
case SFPSTOCHRND_MOD1_FP32_TO_UINT8 : KeepSign = false; MaxMagnitude =   255; break;
case SFPSTOCHRND_MOD1_FP32_TO_INT16 : KeepSign = true ; MaxMagnitude = 32767; break;
case SFPSTOCHRND_MOD1_FP32_TO_UINT16: KeepSign = false; MaxMagnitude = 65535; break;
default:
  // Is some other flavour of SFPSTOCHRND; see other pages for details.
  UndefinedBehaviour();
}

lanewise {
  if (VD < 12 || VD == 16 || LaneConfig.DISABLE_BACKDOOR_LOAD) {
    if (LaneEnabled) {
      uint32_t PRNGBits = StochasticRounding ? AdvancePRNG() & 0x7fffff : 0x400000;
      uint32_t c = LReg[VC].u32; // FP32.
      uint32_t Sign = KeepSign ? (c & 0x80000000u) : 0;
      int32_t Exp = ((c >> 23) & 0xff) - 127;
      uint64_t Mag;
      if (Exp < -1) {
        // |x| < 0.5 always becomes zero.
        Mag = 0;
        Sign = 0;
      } else if (Exp >= 16) {
        // |x| ≥ 2**16 always becomes maximum magnitude, as does NaN.
        Mag = MaxMagnitude;
      } else {
        Mag = 0x800000 | (c & 0x7fffff);
        Mag = (Exp >= 0) ? Mag << Exp : Mag >> -Exp;
        Mag = (Mag >> 23) + ((Mag & 0x7fffff) >= PRNGBits);
        if (Mag > MaxMagnitude) Mag = MaxMagnitude;
        if (Mag == 0) Sign = 0;
      }
      if (VD < 8 || VD == 16) {
        LReg[VD].u32 = Sign + Mag; // Sign-magnitude integer.
      }
    }
  }
}
```

Supporting definitions:
```c
#define SFPSTOCHRND_MOD1_FP32_TO_UINT8  2
#define SFPSTOCHRND_MOD1_FP32_TO_INT8   3
#define SFPSTOCHRND_MOD1_FP32_TO_UINT16 6
#define SFPSTOCHRND_MOD1_FP32_TO_INT16  7
```
