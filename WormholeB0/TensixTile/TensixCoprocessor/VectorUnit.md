# Vector Unit (SFPU)

The Vector Unit (SFPU) performs arithmetic on 32-bit floating-point values or 32-bit integers in [`LReg`](LReg.md). It can be considered as a general-purpose SIMD engine, consisting of 32 lanes of 32 bits.

## Sub-units

The Vector Unit (SFPU) is composed of five sub-units: load, simple, MAD, round, and store. The Vector Unit (SFPU) can only accept one instruction per cycle from the outside world, so by default four fifths of the Vector Unit (SFPU) is always idle. To have more than one sub-unit active at a time, [`SFPLOADMACRO`](SFPLOADMACRO.md) needs to be used.

## `lanewise`

In instruction descriptions, `lanewise` itself is shorthand for `for (unsigned Lane = 0; Lane < 32; ++Lane)`, and then various shorthands apply _within_ a `lanewise` block:

|Syntax|Shorthand for|
|---|---|
|`LReg[i]`|`LReg[i][Lane]`|
|`LaneEnabled`|`LaneEnabled[Lane]`|
|`LaneFlags`|`LaneFlags[Lane]`|
|`UseLaneFlagsForLaneEnable`|`UseLaneFlagsForLaneEnable[Lane]`|
|`FlagStack`|`FlagStack[Lane]`|
|`LaneConfig`|`LaneConfig[Lane]`|
|`LoadMacroConfig`|`LoadMacroConfig[Lane]`|
|`AdvancePRNG()`|`AdvancePRNG(Lane)`|

## Lane Predication Masks

```c
bool LaneFlags[32] = {false};
bool UseLaneFlagsForLaneEnable[32] = {false};
struct FlagStackEntry {
  bool LaneFlags;
  bool UseLaneFlagsForLaneEnable;
};
Stack<FlagStackEntry> FlagStack[32];
```

Software is encouraged to set `UseLaneFlagsForLaneEnable` to `true` and then always leave it as `true`, though it doesn't have to.

In instruction descriptions, `LaneEnabled[Lane]` is shorthand `IsLaneEnabled(Lane)`, whose definition is:

```c
bool IsLaneEnabled(unsigned Lane) {
  if (LaneConfig[Lane & 7].ROW_MASK.Bit[Lane / 8]) {
    return false;
  } else if (UseLaneFlagsForLaneEnable[Lane]) {
    return LaneFlags[Lane];
  } else {
    return true;
  }
}
```

`UseLaneFlagsForLaneEnable` is initially `false`, but once changed to `true` using [`SFPENCC`](SFPENCC.md), `LaneFlags` is used to drive `LaneEnabled` (per the definition of `IsLaneEnabled` above). In turn, `LaneFlags` can be set by the [`SFPENCC`](SFPENCC.md), [`SFPSETCC`](SFPSETCC.md), [`SFPIADD`](SFPIADD.md), [`SFPLZ`](SFPLZ.md), and [`SFPEXEXP`](SFPEXEXP.md) instructions.

The `FlagStack` is used by the [`SFPPUSHC`](SFPPUSHC.md), [`SFPPOPC`](SFPPOPC.md), and [`SFPCOMPC`](SFPCOMPC.md) instructions. Compilers are encouraged to map SIMT `if` / `else` on to this stack. Some kinds of non-uniform control flow can also be accommodated using the `SFPMAD_MOD1_INDIRECT_VA` and/or `SFPMAD_MOD1_INDIRECT_VD` mode flags of the [`SFPMAD`](SFPMAD.md), [`SFPMULI`](SFPMULI.md), and [`SFPADDI`](SFPADDI.md) instructions.

## PRNG

Some modes of the [`SFPMOV`](SFPMOV.md), [`SFPCAST`](SFPCAST.md), and [`SFPSTOCHRND`](SFPSTOCHRND.md) instructions make use of a hardware PRNG, the behaviour of which is:

```c
uint32_t AdvancePRNG(unsigned Lane) {
  static uint32_t State[32];
  uint32_t Result = State[Lane];
  uint32_t Taps = __builtin_popcount(Result & 0x80200003);
  State[Lane] = (~Taps << 31) | (Result >> 1);
  return Result;
}
```

The statistical properties of this PRNG are poor, so software is encouraged to build its own PRNG if high quality randomness is required.
