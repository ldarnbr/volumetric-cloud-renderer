# Project Plan

This is a personal notepad to monitor my progress with the project. This is based on the 
survey of literature around cloud rendering. The method closely resembles Sebastian Lagues process outlined in his [Coding Adventure: Clouds video](https://www.youtube.com/watch?v=4QOcCGI6xOU&list=LL).

The steps of the plan are subject to change if any issues are encountered. The general scope of the work is quite large, so there may be some compromises made on the way. I will aim to keep the plan document up to date if anything does change.

## Completed
- [X] 2D Worley noise generation
- [X] Worley noise tiling to eliminate seams when textures repeat.
- [X] Cellular Worley noise optimisation.
- [X] A slice viewer to inspect volumes.
- [X] Post processing using OnRenderImage.
- [X] Ray box intersection using the slab method.

## Currently Working On
- Raymarching through the cloud volume

## Future Work
- [] Density sampling the 3D noise texture
- [] Beer-Lambert transmittance
- [] Henyey-Greenstein light scattering
- [] Combining Perlin with Worley noise
- [] Performance testing and results
- [] Write up!