Shader "Custom/CloudShaderProcedural"
{
    Properties
    {
        // the frame thats provided by Graphics.Blit (inspector)
        _MainTex ("Texture", 2D) = "white" {}

    }
    SubShader
    {
        // using only a screen image with no depth
        Cull off
        ZWrite off
        ZTest Always
        Pass
        {
            CGPROGRAM
            // function decleration of the vertex and fragment shaders
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram
            #include "UnityCG.cginc"

            // the scene from Graphics.Blit as a 2D texture. Links to the _MainTex in the inspector
            sampler2D _MainTex;

            float3 _CameraWorldPosition;
            float3 _CloudVolumeMinBound;
            float3 _CloudVolumeMaxBound;

            float3 _FrustumCornerTL;
            float3 _FrustumCornerTR;
            float3 _FrustumCornerBL;
            float3 _FrustumCornerBR;

            float _AbsorptionCoefficient;
            float _DensityThreshold;
            float3 _SunDirection;
            float4 _SunColour;
            float _ScatterFactor;
            float _CloudScale;

            int _OctaveCount;

            float _WindTime;

            float _StepSize;
            int _StepLimit;
            float _LightStepSize;
            int _LightStepLimit;

            // data that comes in from unity per vertex
            struct VertexInput
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            // data passed from vertex to fragment
            struct VertexOutput
            {
                float4 screenPosition : SV_POSITION;
                float2 uv : TEXCOORD0;
                // ray direction for the pixel in world space
                float3 rayDirection : TEXCOORD1;
            };

            VertexOutput VertexProgram (VertexInput input)
            {
                VertexOutput output;
                // converts the vertex position from the object to surface space
                output.screenPosition = UnityObjectToClipPos(input.vertex);
                output.uv = input.uv;

                // checks which corner of the screen the pixel is in and assigns the ray direction.
                // in uv coords 0,0 is the bottom left and 1,1 is the top right.
                if (input.uv.x < 0.5 && input.uv.y < 0.5)
                {
                    output.rayDirection = _FrustumCornerBL;
                }
                else if (input.uv.x < 0.5 && input.uv.y >=0.5)
                {
                    output.rayDirection = _FrustumCornerTL;
                }
                else if (input.uv.x >= 0.5 && input.uv.y < 0.5)
                {
                    output.rayDirection = _FrustumCornerBR;
                }
                else
                {
                    output.rayDirection = _FrustumCornerTR;
                }
                return output;
            }

            // -----------------------------------------------------------------------------------------------------------------
            // Procedural Noise Functions
            // -----------------------------------------------------------------------------------------------------------------
            
            /*
            The functions in this sections form the bulk of the changes made to the shader to try resolve the tiling limitations of
            sampling a saved noise texture. These were abstracted to separate C# scripts e.g. PerlinNoise3D.cs and WorleyNoise3D.cs
            in the first 'front loaded' noise generation method. The main difference is that the noise is now generated during the raymarching
            process which comes at some performance cost but much better visual fidelity.
            */

            // Im using the Hash function from user Dave_Hoskins available at:
            // https://www.shadertoy.com/view/4djSRW
            // Particularly the hashOld33 function which he states is a "typical hash function". I chose this in all honesty as it's simple
            // to understand and implement. There are some issues with it though from my wider research.
            
            // Hash functions using trig functions can cause unexpected behaviour between different GPU architectures so this might 
            // be something I change if time allows.
            // Saving this reference I found which outlines some alternatives for future me:
            // file:///C:/Users/ldarn/Downloads/Jarzynski2020Hash%20(3).pdf

            float3 HashCell(float3 cell)
            {
                float x = frac(sin(dot(cell, float3(127.1, 311.7, 74.7))) * 43758.5453);
                float y = frac(sin(dot(cell, float3(269.5, 183.3, 246.1))) * 43758.5453);
                float z = frac(sin(dot(cell, float3(113.5, 271.9, 124.6))) * 43758.5453);
                return float3(x, y, z);
            }

            // this comes from the improved function in Perlin's improving noise paper.
            float Fade(float t)
            {
                return 6 * (t * t * t * t * t) - 15 * (t * t * t * t) + 10 * (t * t * t);
            }

            float Gradient(int hash, float x, float y, float z)
            {

                // gets the remainder of the hash value when divided by 16to cycle through each of the cases.
                // These represent the 12 different gradient directions to the midpoints of each edge in the cube from 
                // the centre of the cube itself.
                switch (hash % 16)
                {
                    /* 
                     case 0 gradient is (1, 1, 0) so a vector with direction diagonally in x and y with no z
                     dot product of gradient and distance x, y, z = (1 * x) + (1 * y) + (0 * z) = x + y
                     see Sreenshot: gradient-vectors-perlin.png
                     'Breaking down Perlin noise reference implementation'
                     Abdelrahman Said
                     Available at: 
                     https://thewizardapprentice.com/2025/10/27/breaking-down-perlin-noise-reference-implementation/
                    */
                    case 0: return x + y;
                    case 1: return -x + y;
                    case 2: return x - y;
                    case 3: return -x - y;
                    case 4: return x + z;
                    case 5: return -x + z;
                    case 6: return x - z;
                    case 7: return -x - z;
                    case 8: return y + z;
                    case 9: return -y + z;
                    case 10: return y - z;
                    case 11: return -y - z;
                    case 12: return y + x;
                    case 13: return -y + z;
                    case 14: return y - x;
                    case 15: return -y - z;
                    default: return 0;
                }
            }

            /*
            This is the GetNoise function in PerlinNoise3D.cs but adapted for the procedural implementation. It is mostly the same,
            but cannot use the permutation table lookup that GenerateTexture used to get the hash values. This was previously 'frontloaded'
            in that it was generated and stored in CPU memory. The GPU doesn't have access to this, so the hash computation is done by 
            the GPU instead.
            */
            float ProceduralPerlin(float3 worldPosition, float scale)
            {
                // take the input coordinates and scale by the frequency set in the slider
                float x = worldPosition.x * scale;
                float y = worldPosition.y * scale;
                float z = worldPosition.z * scale;

                // gets the cubic cell that the position is in (for a unit length cube 1x1x1, 2.7 represents cube 2, hence
                // use Floor)
                int cellX = (int)floor(x) % 256;
                int cellY = (int)floor(y) % 256;
                int cellZ = (int)floor(z) % 256;

                // gets the relative position within the cell (fractional part of the local coordinates)
                float fracX = x - floor(x);
                float fracY = y - floor(y);
                float fracZ = z - floor(z);

                // fade lines for each coordinate
                float fadeX = Fade(fracX);
                float fadeY = Fade(fracY);
                float fadeZ = Fade(fracZ);

                // hash lookup for each of the eight corners.
                // L = Lower = 0, H = Higher = 1. LLL = Corner (0,0,0) etc.

                int LLL = (int)(HashCell(float3(cellX, cellY, cellZ)).x * 255.0);
                int LLH = (int)(HashCell(float3(cellX, cellY, cellZ + 1)).x * 255.0);
                int LHL = (int)(HashCell(float3(cellX, cellY + 1, cellZ)).x * 255.0);
                int HLL = (int)(HashCell(float3(cellX + 1, cellY, cellZ)).x * 255.0);
                int HHH = (int)(HashCell(float3(cellX + 1, cellY + 1, cellZ + 1)).x * 255.0);
                int HHL = (int)(HashCell(float3(cellX + 1, cellY + 1, cellZ)).x * 255.0);
                int HLH = (int)(HashCell(float3(cellX + 1, cellY, cellZ + 1)).x * 255.0);
                int LHH = (int)(HashCell(float3(cellX, cellY + 1, cellZ + 1)).x * 255.0);

                // calculate the gradient influence at each of the 8 corners
                // gradient function takes the hash value and the distance from that corner to the current position
                float gradientLLL = Gradient(LLL, fracX, fracY, fracZ);
                float gradientLLH = Gradient(LLH, fracX, fracY, fracZ - 1);
                float gradientLHL = Gradient(LHL, fracX, fracY - 1, fracZ);
                float gradientHLL = Gradient(HLL, fracX - 1, fracY, fracZ);
                float gradientHHH = Gradient(HHH, fracX - 1, fracY - 1, fracZ - 1);
                float gradientHHL = Gradient(HHL, fracX - 1, fracY - 1, fracZ);
                float gradientHLH = Gradient(HLH, fracX - 1, fracY, fracZ - 1);
                float gradientLHH = Gradient(LHH, fracX, fracY - 1, fracZ - 1);

                // to interpolate between the 8 corner gradients, we need to do it in 3 stages
                // 1. blend along x between corner pairs
                // 2. blend those along y
                // 3. blend that along z
                // This incorporates the fade lines for smoothness around boundaries for Perlins improved noise
                float x1 = lerp(gradientLLL, gradientHLL, fadeX);
                float x2 = lerp(gradientLHL, gradientHHL, fadeX);
                float x3 = lerp(gradientLLH, gradientHLH, fadeX);
                float x4 = lerp(gradientLHH, gradientHHH, fadeX);

                float y1 = lerp(x1, x2, fadeY);
                float y2 = lerp(x3, x4, fadeY);

                float result = lerp(y1, y2, fadeZ);

                return (result + 1.0) / 2.0;
            }

            float ProceduralWorley(float3 worldPosition, float cellSize)
            {
                // normalises the position to be in cell space
                float u = worldPosition.x / cellSize;
                float v = worldPosition.y / cellSize;
                float w = worldPosition.z / cellSize;
                float3 currentPosition = float3(u, v, w);

                // get the cell that the position is in
                int cellX = (int)floor(u);
                int cellY = (int)floor(v);
                int cellZ = (int)floor(w);

                // bound the mininum distance to the random point, to the maximum possible distance
                float minDist = 1e10;

                for (int offsetX = -1; offsetX <= 1; offsetX++)
                {
                    for (int offsetY = -1; offsetY <= 1; offsetY++)
                    {
                        for (int offsetZ = -1; offsetZ <= 1; offsetZ++)
                        {
                            float3 neighbourCell = float3(cellX + offsetX, cellY + offsetY, cellZ + offsetZ);

                            // replaces the pre generated array of points in WorleyNoise3D.cs and instead generates the random
                            // point in the neighbour cell.
                            float3 neighbourPoint = HashCell(neighbourCell);

                            // the absolute position of the neighbour random point in cell space
                            float3 absolutePoint = neighbourCell + neighbourPoint;

                            float dist = distance(currentPosition, absolutePoint);

                            if (dist < minDist)
                            {
                                minDist = dist;
                            }
                        }
                    }
                }

                // Maximum distance is when the pixel is in the corner of a cell and the point is in the opposite corner (unit cube 1x1x1)
                float maxDist = sqrt(3);

                // normalised to 0-1 range relative to the cell size
                float normalised = clamp(minDist / maxDist, 0, 1);

                // inversion so pixels close to the point are bright (bubble like)
                float inverted = 1 - normalised;

                return inverted;
            }

            // -----------------------------------------------------------------------------------------------------------------
            // -----------------------------------------------------------------------------------------------------------------

            // Sources:
            // https://www.scratchapixel.com/lessons/3d-basic-rendering/minimal-ray-tracer-rendering-simple-shapes/ray-box-intersection.html
            // https://www.youtube.com/shorts/GqwUHXvQ7oA
            // https://tavianator.com/2022/ray_box_boundary.html

            float2 RayBoxIntersection(float3 origin, float3 direction, float3 boxMin, float3 boxMax)
            {
                // each axis pair has an entry and exit point, we take the min of the two to get the entry and the max to get the exit
                float3 entryDist = (boxMin - origin) / direction;
                float3 exitDist = (boxMax - origin) / direction;

                // if the ray travels in the negative direction, entry = exit and exit = entry, so take the min and max values to
                // get absolute entry and exit distances
                float3 entries = min(entryDist, exitDist);
                float3 exits = max(entryDist, exitDist);

                // the box is entered at the last axis entry nad exits at the first axis exit
                // concept screenshot located at: ../screenshots/ray-box-intersection.png
                // The pink ball furtherst from the camera is the entry, the blue ball closest is the exit.
                float entry = max(max(entries.x, entries.y), entries.z);
                float exit = min(min(exits.x, exits.y), exits.z);

                return float2(entry, exit);
            }

            /*
            This function uses equation (9) on page 12 of the following reference:
            Physically Based Sky, Atmosphere and Cloud Rendering in frostbite
            Sebastien Hillaire, EA Frostbite
            Available at:
            https://media.contentapi.ea.com/content/dam/eacom/frostbite/files/s2016-pbs-frostbite-sky-clouds-new.pdf
            */
            float HG(float3 rayDirection, float3 sunDirection, float scatterFactor)
            {
                // dot product of a and b = |a| * |b| * cos(theta)
                // for normalised vectors dot(a, b) = cos(theta)
                // when the rays are parallel (aka facing the sun) cosAngle = 1
                // when the rays are opposite cosAngle = -1
                float cosAngle = dot(normalize(rayDirection), normalize(sunDirection));

                float scatterFactor2 = scatterFactor * scatterFactor;

                float numerator = 1.0 - scatterFactor2;
                float denominator = pow(1.0 + scatterFactor2 - 2.0 * scatterFactor * cosAngle, 1.5);
                return numerator / (4.0 * 3.14159 * denominator);
            }

            // sample at points in the direction toward the sun from the current position to calculate transmittance.
            // uses a simplified Beer-Lambert equation to determine how much sunlight reaches the sample point.
            float MarchLight(float3 rayPosition, float3 boxMin, float3 boxMax)
            {
                float stepSize = _LightStepSize;
                int stepLimit = _LightStepLimit;
                float lightDensity = 0;

                for (int i = 0; i < stepLimit; i++)
                {
                    // step through the volume, from the current position in the direction towards the sun
                    rayPosition = rayPosition + _SunDirection * stepSize;

                    // normalise the position to compare to the box coordinates
                    float3 uvwPosition = (rayPosition - boxMin) / (boxMax - boxMin);

                    // need to check if the position is located in the bounding box
                    if (
                        uvwPosition.x >= 0 && uvwPosition.x <= 1 &&
                        uvwPosition.y >= 0 && uvwPosition.y <= 1 &&
                        uvwPosition.z >= 0 && uvwPosition.z <= 1
                    )
                    {
                        // accumulate the light density by sampling the procedural Worley noise
                        lightDensity = lightDensity + ProceduralWorley(rayPosition, 1.0 / _CloudScale) * stepSize;
                    }
                }
                // Beer-Lambert to get the actual amount of light that gets to the point
                return exp(-lightDensity * _AbsorptionCoefficient);
            }

            // what the cloud looks like from our view, marching from the camera through the cloud
            float4 MarchDensity(float entry, float exit, float3 rayOrigin, float3 rayDirection, float3 boxMin, float3 boxMax)
            {
                // how far along the rays path we march before getting the density value
                float stepSize = _StepSize;
                int stepLimit = _StepLimit;

                // total density measured at all steps
                float densityTotal = 0;

                float brightness = 0;

                // gives the distance along the ray where it first hits the box.
                // This is the starting position for the raymarching.
                float3 rayPosition = rayOrigin + rayDirection * entry;

                // distance is measured from the box entry point
                float distanceTravelled = entry;

                // keep incrementing the steps until the exit is reached
                // had to refactor to a for loop because the shader caused errors due to the while loop
                // having different iteration counts. Converted to a for loop with a defined max iterations but 
                // the exit condition is still checked and breaks out once met.
                [loop]
                for (int i = 0; i < stepLimit; i++)
                {

                    if (distanceTravelled > exit)
                    {
                        break;
                    }

                    // position is in world space
                    rayPosition = rayPosition + (rayDirection * stepSize);

                    // new position based on wind speed scrolling
                    float3 scrollPosition = rayPosition + float3(_WindTime, 0, 0);

                    // clouds are currently being abruptly cutoff at the top and bottom faces of the cuboid volume.
                    // Need to gradually reduce the density as these faces are approached to make it look natural.
                    // Could be done for side faces but they shouldn't been seen if the sky stretches far enough.
                    float distToBot = (rayPosition.y - boxMin.y) / (boxMax.y - boxMin.y);
                    float distToTop = 1.0 - distToBot;

                    // This will controll how much of the density is allowed to contribute to the opacity. 1 = Full contribution, 0 = Transparent
                    // (Multiply by 10 to ramp up the fizzle quickly. AKA 0.1 normalised units from the bot will (10%) 
                    // will cause full density contribution
                    float botFizzle = clamp(distToBot * 10.0, 0, 1);
                    float topFizzle = clamp(distToTop * 10.0, 0, 1);

                    // Clouds need to be positioned away from top and bottom to contribute full density
                    float totalFizzle = botFizzle * topFizzle;
                 
                    // REF: https://iquilezles.org/articles/fbm/
                    // FBM implementation adapted from the standard implementation which avoids pow functions.
                    float worleyDensity = 0;
                    float amplitude = 1.0;
                    float frequency = 1.0;
                    float amplitudeTotal = 0.0;

                    /* 
                    Takes the worley noise at increasing frequencies. Each frequency step zooms into the texture to sample even finer
                    details. Each frequency will have different tiling so will help break up the repetition. Amplitude is halved each step
                    which effectively reduces the contribution of higher frequencies. The larger octave 1 sampling contributes the most
                    because it represents the overall cloud shape. The finer details should have less contribution to the brightness/intensity
                    of the cloud.
                    */
                    [loop]
                    for (int octave = 0; octave < _OctaveCount; octave++)
                    {
                        worleyDensity = worleyDensity + ProceduralWorley(scrollPosition * frequency, 1.0 / _CloudScale ) * amplitude;
                        amplitudeTotal = amplitudeTotal + amplitude;
                        amplitude = amplitude * 0.5;
                        frequency = frequency * 2.0;
                    }

                    // normalisation
                    if (amplitudeTotal > 0)
                    {
                        worleyDensity = worleyDensity / amplitudeTotal;
                    } else {
                        worleyDensity = 0;
                    }

                    // sample the procedural Perlin noise to combine with Worley
                    float perlinDensity = ProceduralPerlin(scrollPosition, _CloudScale * 0.8);

                    // combine the two densities by multiplying. Perlin fills in the gaps in low Worley value regions
                    // making gaps between the cells more natural.
                    float density = worleyDensity * perlinDensity * totalFizzle;


                    // setting a threshold density means we can make the clouds more sparse
                    if (density > _DensityThreshold)
                    {
                        // separates opacity and brightness. Before, they were joined and it was causing shadowed areas
                        // to contribute less to the densityTotal. Now densityTotal only controls opacity.
                        densityTotal = densityTotal + density * stepSize;
                        float sunTransmittance = MarchLight(rayPosition, boxMin, boxMax);
                        float cameraTransmittance = exp(-densityTotal * _AbsorptionCoefficient);
                        float scatter = HG(rayDirection, _SunDirection, _ScatterFactor);

                        brightness = brightness + density * sunTransmittance * cameraTransmittance * scatter * stepSize * 0.5;
                    }

                    distanceTravelled = distanceTravelled + stepSize;
                }

                /* 
                I'm applying a simplified version of Beer-Lambert transmittance. The actual equation
                involves the molar absoption coefficient and molar concentration, as its used in chemistry
                when evaluating transmittance through actual substances:
                REF: https://www.edinst.com/resource/the-beer-lambert-law/
                In this approximation, the _AbsorptionCoefficient is some factor that we can control to 
                dynamically adjust the style of the clouds. We use the negative exponent because light 
                naturally falls off travelling through a volume.
                    
                cloudTransmittance = 1 -> Transparent
                cloudTransmittance = 0 -> Fully opaque
                */
                float cloudTransmittance = exp(-densityTotal * _AbsorptionCoefficient);
                float3 cloudColour = brightness * _SunColour.rgb;
                return float4(cloudColour, 1 - cloudTransmittance);
            }

            // DOCS:
            // https://docs.unity3d.com/2020.1/Documentation/Manual/SL-ShaderSemantics.html
            float4 FragmentProgram (VertexOutput input) : SV_Target
            {
                // gets the original colour in the scene for this pixel
                float4 originalColour = tex2D(_MainTex, input.uv);

                // casts a ray from the camera through the pixel
                float3 origin = _CameraWorldPosition;

                // This caused significant bugs because the previous implementation wasn't normalised. 
                // This meant the distance which was being read relative to the far clip plane was a large amount of
                // units, causing the rays in the marcher to just step past the entire volume instantly, so no
                // density gradient was being shown. Normalize keeps the value at 1 so the number of steps can properly
                // be controlled (e.g. a cube 10x10x10 through the center with a step size of 0.1 is 100 steps to sample density).
                float3 direction = normalize(input.rayDirection);

                // check the ray to see if it intersects the cloud volume box
                float2 intersection = RayBoxIntersection(origin, direction, _CloudVolumeMinBound, _CloudVolumeMaxBound);
                float entry = intersection.x;
                float exit = intersection.y;

                // we can be certain the ray has intersected the box when the furthest entry
                // is closer to the camera than the closes exit.
                if (entry < exit)
                {
                    float4 cloudColour = MarchDensity(entry, exit, origin, direction, _CloudVolumeMinBound, _CloudVolumeMaxBound);
                    
                    // need to linearly interpolate the colour because the screen does not consider the alpha channel
                    // at alpha = 0, the colour will be the originalColour (aka the cloud has transparency)
                    // at alpha = 1, the cloud will be fully opaque white
                    return lerp(originalColour, cloudColour, cloudColour.a);
                }

                // pixels that dont intersect are lef alone
                return originalColour;
            }
            ENDCG
        }
    }
}