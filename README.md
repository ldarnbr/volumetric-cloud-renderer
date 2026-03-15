# Volumetric Cloud Renderer

A real time volumetric cloud renderer that is built in Unity 2022.3 as part of 
my final year BSc Computer Science project.

## Goal
This project aims to create a volumetric cloud rendering system from scratch. It
is inspired by the Presentation delivered by Andrew Schneider and Nathan Vos
["The Real Time Volumetric Cloudscapes of Horizon: Zero Dawn"](https://d3d3g8mu99pzk9.cloudfront.net/AndrewSchneider/The-Real-time-Volumetric-Cloudscapes-of-Horizon-Zero-Dawn.pdf), which uses 
Perlin-Worley noise generation through to raymarching to render
cloud volumes that look realistic without unacceptable performance trade-offs.

## Methodology
My approach will start with the very fundamental 2D concepts and expand into
full volumetric rendering in incremental stages. 

## Progress
1. 2D Worley noise generation
2. Worley noise tiling to eliminate seams when textures repeat
3. Cellular Worley noise optimisation (Worley, 1996)
4. A slice viewer to inspect volumes
5. Post processing using OnRenderImage
6. Ray box intersection using the slab method (Kay et al, 1986)
7. Raymarching with density sampling the 3D noise texture
8. Beer-Lambert Transmittance (Edinburgh Instruments, 2021)
9. Light marching with opacity/brightness accumulation
10. Sun colour tinting
11. Henyey-Greenstein light scattering (Hillaire, 2016)
12. World space noise sampling for cloud volume scaling

## How to Install
1. Clone the repository

```bash
git clone https://github.com/ldarnbr/volumetric-cloud-renderer.git
```

2. Open Unity Hub
3. Click Add -> Add project from disk -> select the 'volumetric-cloud-renderer' folder.
4. Select the project to open!

## Additional Material
For more complicated concepts, i've included a folder with graphic(s) inside.
These will be referenced in comments of my code directly to help illustrate
what the code aims to achieve. These will be cited below, along with other
references used to implement the various algorithms/approaches I went with.

## References
