Shader "Custom/CloudShader"
{
    Properties
    {
        // the frame thats provided by Graphics.Blit (inspector)
        _MainTex ("Texture", 2D) = "white" {}

    }
    SubShader
    {
        // using only a screen image with no depth
        Cull Off
        ZWrite Off
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

            // the 3D noise texture for density sampling
            sampler3D _NoiseTex;

            // perlin noise texture to break up the worley noise
            sampler3D _PerlinTex;

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
                float stepSize = 0.2;
                int stepLimit = 6;
                float lightDensity = 0;

                for (int i = 0; i < stepLimit; i++)
                {
                    // step through the volume, from the current position in the direction towards the sun
                    rayPosition = rayPosition + _SunDirection * stepSize;

                    // normalise the position to compare to the box coordinates
                    float3 uvwPosition = (rayPosition - boxMin) / (boxMax - boxMin);

                    float3 worldScaledRay = rayPosition *_CloudScale;

                    // need to check if the position is located in the bounding box
                    if (
                        uvwPosition.x >= 0 && uvwPosition.x <= 1 &&
                        uvwPosition.y >= 0 && uvwPosition.y <= 1 &&
                        uvwPosition.z >= 0 && uvwPosition.z <= 1
                    )
                    {
                        // accumulate the light density from the noise texture, accounting for stepSize
                        lightDensity = lightDensity + tex3D(_NoiseTex, worldScaledRay).r * stepSize;
                    }
                }
                // Beer-Lambert to get the actual amount of light that gets to the point
                return exp(-lightDensity * _AbsorptionCoefficient);
            }

            // what the cloud looks like from our view, marching from the camera through the cloud
            float4 MarchDensity(float entry, float exit, float3 rayOrigin, float3 rayDirection, float3 boxMin, float3 boxMax)
            {
                // how far along the rays path we march before getting the density value
                float stepSize = 1.0;

                // total density measured at all steps
                float densityTotal = 0;

                float brightness = 0;

                // gives the distance along the ray where it first hits the box.
                // This is the starting position for the raymarching.
                float3 rayPosition = rayOrigin + rayDirection * entry;

                // distance is measured from the box entry point
                float distanceTravelled = entry;

                int stepLimit = 200;

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

                    // the world position of the ray is used to sample the noise. This makes the noise tile rather
                    // than stretch when the volume box is adjusted.
                    float3 worldScaledRay = rayPosition * _CloudScale;

                    // supply the uvw coordinates of the ray to sample the 3D texture at that position.
                    // reads from the red channel but the values are the same across rgb channels from WorleyNoise3D
                    float worleyDensity = tex3D(_NoiseTex, worldScaledRay).r;
                    float perlinDensity = tex3D(_PerlinTex, worldScaledRay).r;

                    // combine the two densities by multiplying. Perlin fills in the gaps in low Worley value regions
                    // making gaps between the cells more natural.
                    float density = worleyDensity * perlinDensity;


                    // setting a threshold density means we can make the clouds more sparse
                    if (density > _DensityThreshold)
                    {
                        // separates opacity and brightness. Before, they were joined and it was causing shadowed areas
                        // to contribute less to the densityTotal. Now densityTotal only controls opacity.
                        densityTotal = densityTotal + density * stepSize;
                        float sunTransmittance = MarchLight(rayPosition, boxMin, boxMax);
                        float cameraTransmittance = exp(-densityTotal * _AbsorptionCoefficient);
                        float scatter = HG(rayDirection, _SunDirection, _ScatterFactor);

                        brightness = brightness + density * sunTransmittance * cameraTransmittance * scatter * stepSize * 20;
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
