# Wormhole

Each Wormhole ASIC contains:
* [80x Tensix tile](TensixTile/README.md), also known as worker tiles or compute tiles. Depending on the particular product, either 64 or 72 or 80 will be available, with the others fused off.
* 18x DRAM tile, collectively exposing 12 GiB of GDDR6 (each 2 GiB is exposed identically on 3 tiles).
* 16x Ethernet tile, each one with bidirectional 100 GbE connectivity. Depending on the particular product, some of these tiles will not be connected to anything - they can still be used (for their RISCV and their L1), but they'll never receive any ethernet packets, nor will transmitted packets go anywhere.
* 1x PCI Express tile, for PCI Express 4.0 x16 connectivity with a host system. For products containing multiple ASICs, some of these tiles will not be connected to anything.
* 1x ARC tile, for management purposes. Customers can mostly ignore this tile.
