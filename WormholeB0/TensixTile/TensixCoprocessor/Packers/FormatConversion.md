# Format Conversion

Two data format conversions happen during the pipeline of each packer: an early conversion just after reading datums from `Dst`, and a late conversion just before writing datums to `L1`. To avoid double rounding, software should ensure that at least one conversion is an identity conversion, or ensure that both conversions are truncating. In general, the early format conversion should be used to make types narrower using rounding, and the late format conversion should be used to make types wider. To make types narrower using truncation, it is sometimes the case that either conversion could be used, in which case the early conversion should be preferred.

## Early format conversion

If fetching datums from `Dst` (as is usually the case), the early format conversion will take datums in one of the five formats supported by `Dst` and convert them to one of the supported intermediate floating-point or integer formats:

||From FP32 (e8m23)|From BF16 (e8m7)|From FP16 (e5m10)|From INT32 (e0m31)|From INT16 (e0m15)|
|---|---|---|---|---|---|
|**To FP32 (e8m23)**|Identity|Yes (though more efficient to keep as BF16 then use late conversion)|No (keep as FP16 then use late conversion)|Bitcast|No|
|**To TF32 (e8m10)**|Rounding|Yes (though more efficient to keep as BF16 then use late conversion)|No (keep as FP16 then use late conversion)|Bitcast to FP32 then rounding|No|
|**To BF16 (e8m7)**|Rounding or truncation|Identity|No (keep as FP16 then use late conversion)|Bitcast of top 16 bits|No|
|**To E8M6**|Rounding|Rounding|No|No|No|
|**To FP16 (e5m10)**|No (keep as FP32 then use late conversion, or round to TF32 then use late conversion)|No (keep as BF16 then use late conversion)|Identity|No|No|
|**To E5M7**|No|No|Truncation|No|No|
|**To E5M6**|No|No|Rounding|No|No|
|**To FP8 (e5m2)**|No (keep as FP32 then use late conversion)|No (keep as BF16 then use late conversion)|Truncation|No|No|
|**To INT32 (e0m31)**|Bitcast|Bitcast (as if FP32)|No|Identity|No|
|**To INT16 (e0m15)**|No|No|No|No|Identity|
|**To INT8 (e0m7)**|Sign bit and low 7 bits of mantissa|Sign bit only, other bits zero|Sign bit only, other bits zero|Shift then round then saturate (-127 to +127), or sign bit and low 7 bits of magnitude|No|
|**To UINT8**|Low 8 bits of mantissa|Zero|No|Shift then round then saturate (0 to 255), or low 8 bits of magnitude|No|

Where rounding is supported, it can either be deterministic round-to-nearest with ties away from zero, or stochastic (though due to a hardware bug, stochastic rounding has a slight bias towards increasing the magnitude rather than being 50:50, and can even sometimes increase the magnitude of values which do not require rounding).

If Packer 0 is fetching datums from L1 rather than from `Dst`, then the early format conversion does not happen, and the datums from L1 need to occupy a whole number of bytes:
||From 32b in L1|From 16b in L1|From 8b in L1|
|---|---|---|---|
|**To FP32 (e8m23)**|Identity|No|No|
|**To TF32 (e8m10)**|No|No|No|
|**To BF16 (e8m7)**|No|Identity|Sign and mantissa from 8b, exponent zero|
|**To E8M6**|No|No|No|
|**To FP16 (e5m10)**|No|Identity|No|
|**To E5M7**|No|No|Sign and mantissa from 8b, exponent zero|
|**To E5M6**|No|No|No|
|**To FP8 (e5m2)**|No|No|Identity|
|**To INT32**|Identity|Shifted left by 16 bits; bottom bits filled with zero|Shifted left by 24 bits; bottom bits filled with zero|
|**To INT16**|Uses top 16 bits; bottom 16 discarded|Identity|Shifted left by 8 bits; bottom bits filled with zero|
|**To INT8 or UINT8**|No|Uses top 8 bits; bottom 8 discarded|Identity|

## Late format conversion

The late format conversion takes one of the supported intermediate formats, and converts it to a format supported by L1:

<table><tr><th/><th>From FP32</th><th>From TF32 or BF16 or E8M6 or FP16 or E5M7 or E5M6 or FP8</th><th>From INT32</th><th>From INT16</th><th>From INT8 or UINT8</th></tr>
<tr><th>To FP32 or BF16</th><td colspan="2">Truncate if there is narrowing of mantissa</td><td colspan="3">No</td></tr>
<tr><th>To TF32</th><td>No (use early conversion)</td><td>Yes (all bits preserved; no rounding or truncation or saturation ever required)</td><td colspan="3">No</td></tr>
<tr><th>To FP16 or FP8</th><td colspan="2">Saturate if there is narrowing of exponent, then truncate if there is narrowing of mantissa</td><td colspan="3">No</td></tr>
<tr><th>To BFP8</th><td colspan="2">Converted to BF16 (as per first row), then round to BFP8 with one shared 8b exponent per 16 datums</td><td colspan="3">No</td></tr>
<tr><th>To BFP4 or BFP2</th><td colspan="2">Converted to BFP8 (as per the above row), then truncate to BFP4 or BFP2</td><td colspan="3">No</td></tr>
<tr><th>To BFP8a</th><td colspan="2">Converted to E5M7 (saturate if there is narrowing of exponent, then truncate if there is narrowing of mantissa), then round to BFP8a with one shared 5b exponent per 16 datums</td><td colspan="3">No</td></tr>
<tr><th>To BFP4a or BFP2a</th><td colspan="2">Converted to BFP8a (as per the above row), then truncate to BFP4a or BFP2a</td><td colspan="3">No</td></tr>
<tr><th>To INT32</th><td colspan="2">No</td><td>Identity</td><td>No</td><td>No</td></tr>
<tr><th>To INT16</th><td colspan="2">No</td><td>No</td><td>Identity</td><td>No</td></tr>
<tr><th>To INT8 or UINT8</th><td colspan="2">No</td><td>No</td><td>No</td><td>Identity or bitcast</td></tr>
</table>

Where saturation happens due to narrowing of exponents, large values (including infinities) get converted to NaN, and small values get converted to zero (or occasionally to _some_ unrelated denormal value). To ensure correct handling of small values when converting types with 8-bit exponents (such as FP32 and BF16) to types with 5-bit exponents (such as FP16 and FP8), the exponent thresholding feature of the packer can be used to ensure that potentially-denormal values get converted to zero before they reach the late format conversion. For better handling of large values, the Vector Unit (SFPU) can be used to massage data prior to packing.

Where rounding happens in BFP conversions, it can either be deterministic round-to-nearest with ties away from zero, or stochastic (though due to a hardware bug, stochastic rounding has a slight bias towards increasing the magnitude rather than being 50:50, and can even sometimes increase the magnitude of values which do not require rounding).

For all BFP formats, there is a separate output stream in L1 for the exponents, consisting of one byte per 16 datums.

For all BFP4 formats, two datums are packed in to each byte of L1. For all BFP2 formats, four datums are packed in to each byte of L1.

## Configuring the conversions

The early format conversion is configured using a variety of configuration fields, taking different values based on the desired conversion:

* **From FP32 or BF16 or INT32:**
  * Set `Read_32b_data = true` if from FP32 or from INT32, `Read_32b_data = false` if from BF16. Then:
  * **To FP32 or INT32:** Set `IntermediateFormat = INT32`, or `IntermediateFormat = FP32` and either `Round_10b_mant = false` or `Read_raw = true`, or `IntermediateFormat = TF32` and `Read_raw = true`.
  * **To TF32:** Set `Read_raw = false`. Then set `IntermediateFormat = TF32`, or `IntermediateFormat = FP32` and `Round_10b_mant = true`. If the late conversion is from TF32 to FP16, can also use `IntermediateFormat = BF16` and `Round_10b_mant = true`.
  * **To BF16:**
    * **Rounding:** Set `IntermediateFormat = BF16` and `Read_raw = false`. If the late conversion is from BF16 to FP16, also set `Round_10b_mant = false`.
    * **Truncating:** Set `IntermediateFormat = BFP8` and `Read_raw = true`.
  * **To E8M6:** Set `IntermediateFormat = BFP8` and `Read_raw = false`.
  * **To INT8:** Set `IntermediateFormat = INT8` and `Read_unsigned = false`. Then:
    * **Sign bit and low seven bits:** Set `Read_raw = true`.
    * **Shifting, rounding, and saturating:** Set `Read_raw = false`. Set the low five bits of `ShiftAmount` to the desired right-shift amount; note that this shifts the magnitude right, leaves the sign bit as-is, and fills the gap with zeros. The shifted-out bits (if any) are used for rounding.
  * **To UINT8:** Set `IntermediateFormat = INT8` and `Read_unsigned = true`. Then:
    * **Low eight bits:** Set `Read_raw = true`.
    * **Shifting, rounding, and saturating:** Set `Read_raw = false`. Set the low five bits of `ShiftAmount` to the desired right-shift amount; note that this shifts the magnitude right, leaves the sign bit as-is, and fills the gap with zeros. The shifted-out bits (if any) are used for rounding.
* **From FP16:**
  * Set `Read_32b_data = false`, then:
  * **To FP16:** Set `IntermediateFormat = FP16`.
  * **To E5M7:** Set `IntermediateFormat = BFP8a` and `Read_raw = true`.
  * **To E5M6:** Set `IntermediateFormat = BFP8a` and `Read_raw = false`.
  * **To FP8:** Set `IntermediateFormat = FP8` and `Read_raw = true`.
  * **To INT8 (sign bit only, other bits zero):** Set `IntermediateFormat = INT8` and `Read_unsigned = false` and `Read_raw = true`.
* **From INT16:**
  * Set `Read_32b_data = false`, then:
  * **To INT16:** Set `IntermediateFormat = INT16`.

The mapping of variables in the above to concrete configuration fields is:

```c
uint1_t StateID = ThreadConfig[CurrentThread].CFG_STATE_ID_StateID;
auto& ConfigState = Config[StateID];

Read_32b_data  is ConfigState.PCK_DEST_RD_CTRL_Read_32b_data;
Round_10b_mant is ConfigState.PCK_DEST_RD_CTRL_Round_10b_mant;
Read_raw       is ConfigState.PCK_DEST_RD_CTRL_Read_int8;
Read_unsigned  is ConfigState.PCK_DEST_RD_CTRL_Read_unsigned;

if (ConfigState.ALU_FORMAT_SPEC_REG_Dstacc_override) {
  IntermediateFormat is ConfigState.ALU_FORMAT_SPEC_REG_Dstacc_val;
} else {
  IntermediateFormat is ConfigState.ALU_FORMAT_SPEC_REG2_Dstacc;
}

if (ConfigState.INT_DESCALE_Enable) {
  if (ConfigState.INT_DESCALE_Mode) {
    ShiftAmount is Config.INT_DESCALE_VALUES_SEC[(z & 63) >> 2].Value >> ((z & 3) * 8); // For some value z
  } else {
    ShiftAmount is Config.INT_DESCALE_VALUES_SEC0_Value;
  }
} else {
  ShiftAmount is 0;
}
```

The late format conversion is configured using the `LateFromFormat` and `LateToFormat` variables, which map to concrete configuration fields as:
```c
uint1_t StateID = ThreadConfig[CurrentThread].CFG_STATE_ID_StateID;

LateFromFormat is CurrentPacker.Config[StateID].In_data_format;
LateToFormat   is CurrentPacker.Config[StateID].Out_data_format;
```

It is usually the case that `IntermediateFormat` and `LateToFormat` should be set to the same value. All three of `IntermediateFormat` and `LateFromFormat` and `LateToFormat` are 4-bit fields, with the encoding of data type names being:

||`0b??11`|`0b??10`|`0b??01`|`0b??00`|
|---|---|---|---|---|
|**`0b00??`**|`BFP4a` (‡)|`BFP8a` (†)|`FP16`|`FP32`|
|**`0b01??`**|`BFP4` (‡)|`BFP8` (†)|`BF16`|`TF32`|
|**`0b10??`**|`BFP2a` (‡)|`FP8`|`INT16`|`INT32`|
|**`0b11??`**|`BFP2` (‡)|`INT8`|||

(†) Only actually _means_ BFP in `LateToFormat`. Elsewhere it usually represents a type with the same exponent and mantissa width as the BFP format, but with the exponent being per-datum rather than one common exponent per 16 datums. In the case of BFP8, this gives a type almost identical to BF16.

(‡) Only valid in `LateFromFormat`, not valid in `IntermediateFormat` or `LateFromFormat`.
