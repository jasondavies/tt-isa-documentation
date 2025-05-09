# Floating-point bit patterns

The Tensix coprocessor does not entirely conform to IEEE 754. For the various floating-point formats supported by arithmetic instructions within the coprocessor, this page outlines the IEEE 754 interpretation of various bit patterns, along with the coprocessor interpretation of those bit patterns.

Software running on the host system will generally expect IEEE 754 interpretation of various bit patterns, so to bridge the gap between the interpretations, software may want to perform a pre-processing step before presenting data to the coprocessor, and similarly perform a post-processing step after receiving data back from the coprocessor. This is especially true for FP16 data.

## FP32

<table><thead><tr><th>Sign</th><th>Exp&nbsp;(8b)</th><th>Mant&nbsp;(23b)</th><th>IEEE 754</th><th>Vector Unit (SFPU)</th><th>Matrix Unit (FPU)</th></tr></thead>
<tr><td>0</td><td>255</td><td>Non-zero</td><td colspan="2">+NaN</td><td>(1 + Mant/2<sup>23</sup>) * 2<sup>Exp-127</sup> (†)</td></tr>
<tr><td>0</td><td>255</td><td>0</td><td colspan="2">+Infinity</td><td>(1 + Mant/2<sup>23</sup>) * 2<sup>Exp-127</sup> (‡)</td></tr>
<tr><td>0</td><td>1 - 254</td><td>Any</td><td colspan="3">(1 + Mant/2<sup>23</sup>) * 2<sup>Exp-127</sup></td></tr>
<tr><td>0</td><td>0</td><td>Non-zero</td><td>(0 + Mant/2<sup>23</sup>) * 2<sup>-126</sup></td><td colspan="2">+0 (†)</td></tr>
<tr><td>0</td><td>0</td><td>0</td><td colspan="3">+0</td></tr>
<tr><td>1</td><td>0</td><td>0</td><td colspan="2">-0</td><td>-0 (†)</td></tr>
<tr><td>1</td><td>0</td><td>Non-zero</td><td>-(0 + Mant/2<sup>23</sup>) * 2<sup>-126</sup></td><td colspan="2">-0 (†)</td></tr>
<tr><td>1</td><td>1 - 254</td><td>Any</td><td colspan="3">-(1 + Mant/2<sup>23</sup>) * 2<sup>Exp-127</sup></td></tr>
<tr><td>1</td><td>255</td><td>0</td><td colspan="2">-Infinity</td><td>-(1 + Mant/2<sup>23</sup>) * 2<sup>Exp-127</sup> (‡)</td></tr>
<tr><td>1</td><td>255</td><td>Non-zero</td><td colspan="2">-NaN</td><td>-(1 + Mant/2<sup>23</sup>) * 2<sup>Exp-127</sup> (†)</td></tr></table>

(†) Arithmetic instructions will never produce this bit pattern as an output, but if this bit pattern is presented as an input, it'll be interpreted as shown.

(‡) In some contexts, this bit pattern behaves similarly to ±Infinity, as the Matrix Unit (FPU) will output this bit pattern for values whose magnitude is too large to represent.

When the Vector Unit (SFPU) emits a NaN value, the mantissa will be _some_ non-zero value: the least significant bit of the mantissa will always be set, and the remaining bits may or may not be set.

## TF32

There is no IEEE 754 specification for this type, but one can be reasonably inferred by starting with IEEE 754 FP32 and then truncating the mantissa down to 10 bits.

<table><thead><tr><th>Sign</th><th>Exp&nbsp;(8b)</th><th>Mant&nbsp;(10b)</th><th>Truncated IEEE 754 FP32</th><th>Matrix Unit (FPU)</th></tr></thead>
<tr><td>0</td><td>255</td><td>Non-zero</td><td>+NaN</td><td>(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-127</sup> (†)</td></tr>
<tr><td>0</td><td>255</td><td>0</td><td>+Infinity</td><td>(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-127</sup> (‡)</td></tr>
<tr><td>0</td><td>1 - 254</td><td>Any</td><td colspan="2">(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-127</sup></td></tr>
<tr><td>0</td><td>0</td><td>Non-zero</td><td>(0 + Mant/2<sup>10</sup>) * 2<sup>-126</sup></td><td>+0 (†)</td></tr>
<tr><td>0</td><td>0</td><td>0</td><td colspan="2">+0</td></tr>
<tr><td>1</td><td>0</td><td>0</td><td>-0</td><td>-0 (†)</td></tr>
<tr><td>1</td><td>0</td><td>Non-zero</td><td>-(0 + Mant/2<sup>10</sup>) * 2<sup>-126</sup></td><td>-0 (†)</td></tr>
<tr><td>1</td><td>1 - 254</td><td>Any</td><td colspan="2">-(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-127</sup></td></tr>
<tr><td>1</td><td>255</td><td>0</td><td>-Infinity</td><td>-(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-127</sup> (‡)</td></tr>
<tr><td>1</td><td>255</td><td>Non-zero</td><td>-NaN</td><td>-(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-127</sup> (†)</td></tr></table>

(†) Arithmetic instructions will never produce this bit pattern as an output, but if this bit pattern is presented as an input, it'll be interpreted as shown.

(‡) In some contexts, this bit pattern behaves similarly to ±Infinity, as the Matrix Unit (FPU) will output this bit pattern for values whose magnitude is too large to represent.

## BF16

There is no IEEE 754 specification for this type, but one can be reasonably inferred by starting with IEEE 754 FP32 and then truncating the mantissa down to 7 bits.

<table><thead><tr><th>Sign</th><th>Exp&nbsp;(8b)</th><th>Mant&nbsp;(7b)</th><th>Truncated IEEE 754 FP32</th><th>Vector Unit (SFPU)</th><th>Matrix Unit (FPU)</th></tr></thead>
<tr><td>0</td><td>255</td><td>Non-zero</td><td colspan="2">+NaN</td><td>(1 + Mant/2<sup>7</sup>) * 2<sup>Exp-127</sup> (†)</td></tr>
<tr><td>0</td><td>255</td><td>0</td><td colspan="2">+Infinity</td><td>(1 + Mant/2<sup>7</sup>) * 2<sup>Exp-127</sup> (‡)</td></tr>
<tr><td>0</td><td>1 - 254</td><td>Any</td><td colspan="3">(1 + Mant/2<sup>7</sup>) * 2<sup>Exp-127</sup></td></tr>
<tr><td>0</td><td>0</td><td>Non-zero</td><td>(0 + Mant/2<sup>7</sup>) * 2<sup>-126</sup></td><td colspan="2">+0 (†)</td></tr>
<tr><td>0</td><td>0</td><td>0</td><td colspan="3">+0</td></tr>
<tr><td>1</td><td>0</td><td>0</td><td colspan="2">-0</td><td>-0 (†)</td></tr>
<tr><td>1</td><td>0</td><td>Non-zero</td><td>-(0 + Mant/2<sup>7</sup>) * 2<sup>-126</sup></td><td colspan="2">-0 (†)</td></tr>
<tr><td>1</td><td>1 - 254</td><td>Any</td><td colspan="3">-(1 + Mant/2<sup>7</sup>) * 2<sup>Exp-127</sup></td></tr>
<tr><td>1</td><td>255</td><td>0</td><td colspan="2">-Infinity</td><td>-(1 + Mant/2<sup>7</sup>) * 2<sup>Exp-127</sup> (‡)</td></tr>
<tr><td>1</td><td>255</td><td>Non-zero</td><td colspan="2">-NaN</td><td>-(1 + Mant/2<sup>7</sup>) * 2<sup>Exp-127</sup> (†)</td></tr></table>

(†) Arithmetic instructions will never produce this bit pattern as an output, but if this bit pattern is presented as an input, it'll be interpreted as shown.

(‡) In some contexts, this bit pattern behaves similarly to ±Infinity, as the Matrix Unit (FPU) will output this bit pattern for values whose magnitude is too large to represent.

## FP16

<table><thead><tr><th>Sign</th><th>Exp&nbsp;(5b)</th><th>Mant&nbsp;(10b)</th><th>IEEE 754</th><th>Vector Unit (SFPU)</th><th>Matrix Unit (FPU)</th></tr></thead>
<tr><td>0</td><td>31</td><td>1023</td><td>+NaN</td><td>(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-15</sup> or +Infinity</td><td>(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-15</sup> (‡)</td></tr>
<tr><td>0</td><td>31</td><td>1 - 1022</td><td>+NaN</td><td colspan="2">(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-15</sup></td></tr>
<tr><td>0</td><td>31</td><td>0</td><td>+Infinity</td><td colspan="2">(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-15</sup></td></tr>
<tr><td>0</td><td>1 - 30</td><td>Any</td><td colspan="3">(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-15</sup></td></tr>
<tr><td>0</td><td>0</td><td>Non-zero</td><td>(0 + Mant/2<sup>10</sup>) * 2<sup>-14</sup></td><td><a href="SFPLOADI.md"><code>SFPLOADI</code></a>: (1 + Mant/2<sup>10</sup>) * 2<sup>Exp-15</sup><br/><a href="SFPLOAD.md"><code>SFPLOAD</code></a>: (0 + Mant/2<sup>10</sup>) * 2<sup>-126</sup> (*)</td><td>+0 (†)</td></tr>
<tr><td>0</td><td>0</td><td>0</td><td>+0</td><td><a href="SFPLOADI.md"><code>SFPLOADI</code></a>: (1 + Mant/2<sup>10</sup>) * 2<sup>Exp-15</sup><br/><a href="SFPLOAD.md"><code>SFPLOAD</code></a> and <a href="SFPSTORE.md"><code>SFPSTORE</code></a>: +0</td><td>+0</td></tr>
<tr><td>1</td><td>0</td><td>0</td><td>-0</td><td><a href="SFPLOAD.md"><code>SFPLOAD</code></a> and <a href="SFPSTORE.md"><code>SFPSTORE</code></a>: -0<br/><a href="SFPLOADI.md"><code>SFPLOADI</code></a>: -(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-15</sup></td><td>-0 (†)</td></tr>
<tr><td>1</td><td>0</td><td>Non-zero</td><td>-(0 + Mant/2<sup>10</sup>) * 2<sup>-14</sup></td><td><a href="SFPLOAD.md"><code>SFPLOAD</code></a>: -(0 + Mant/2<sup>10</sup>) * 2<sup>-126</sup> (*)<br/><a href="SFPLOADI.md"><code>SFPLOADI</code></a>: -(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-15</sup></td><td>-0 (†)</td></tr>
<tr><td>1</td><td>1 - 30</td><td>Any</td><td colspan="3">-(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-15</sup></td></tr>
<tr><td>1</td><td>31</td><td>0</td><td>-Infinity</td><td colspan="2">-(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-15</sup></td></tr>
<tr><td>1</td><td>31</td><td>1 - 1022</td><td>-NaN</td><td colspan="2">-(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-15</sup></td></tr>
<tr><td>1</td><td>31</td><td>1023</td><td>-NaN</td><td>-(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-15</sup> or -Infinity</td><td>-(1 + Mant/2<sup>10</sup>) * 2<sup>Exp-15</sup> (‡)</td></tr></table>

(†) Arithmetic instructions will never produce this bit pattern as an output, but if this bit pattern is presented as an input, it'll be interpreted as shown.

(‡) In some contexts, this bit pattern behaves similarly to ±Infinity, as the Matrix Unit (FPU) will output this bit pattern for values whose magnitude is too large to represent (as will [`SFPSTORE`](SFPSTORE.md)), and [`SFPLOAD`](SFPLOAD.md) can optionally be configured to interpret this bit pattern as ±Infinity.

(*) This will become an FP32 denormal, which subsequent arithmetic instructions within the Vector Unit (FPU) will interpret as zero.
