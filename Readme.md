-=(TaitoF2_Senhor notes)=-

Tested: Working Video 720p, 1080p & sound.

___
# TaitoF2 Alpha

Author: [wickerwaka](https://github.com/wickerwaka)

Supported games: Cameltry, Dino Rex, Don Doko Don, Drift Out, Final Blow, Growl, Gun & Frontier, Liquid Kids, Majestic Twelve, Mega Blast, Runark, Solitary Fighter, Super Space Invaders '91

____
HARDWARE DESCRIPTION

Main CPU : MC68000 @ 12MHz

Sound CPU : Z80 @ 4MHz

Sound chip : YM2610

Tilemap Generator : TC0100SCN

Palette Generator : TC0070RGB

Priority Manager / Palette RAM Interface : TC0110PR

Sprite Generators : TC0200OBJ and TC0210FBC (TC0540OBN and TC0520TBC are later versions)

Sound Interface : TC0140SYT (earlier ver. of TC0530SYC)

Video resoution : 320x224

Hardware Features : The main board supports three 64x64 tiled scrolling background planes of 8x8 tiles, and a powerful sprite engine capable of handling all the video chores by itself (used in e.g. Super Space Invaders). The front tilemap has characters which are generated in RAM for maximum versatility (fading effects etc.).
F1 Hardware is very similar and has additional gfx chips e.g. for a zooming/rotating tilemap, or additional tilemap planes.





