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

            float3 _CameraWorldPosition;
            float3 _CloudVolumeMinBound;
            float3 _CloudVolumeMaxBound;

            float3 _FrustumCornerTL;
            float3 _FrustumCornerTR;
            float3 _FrustumCornerBL;
            float3 _FrustumCornerBR;

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

            // DOCS:
            // https://docs.unity3d.com/2020.1/Documentation/Manual/SL-ShaderSemantics.html
            float4 FragmentProgram (VertexOutput input) : SV_Target
            {
                // gets the original colour in the scene for this pixel
                float4 originalColour = tex2D(_MainTex, input.uv);

                // casts a ray from the camera through the pixel
                float3 origin = _CameraWorldPosition;
                float3 direction = input.rayDirection;

                // check the ray to see if it intersects the cloud volume box
                float2 intersection = RayBoxIntersection(origin, direction, _CloudVolumeMinBound, _CloudVolumeMaxBound);
                float entry = intersection.x;
                float exit = intersection.y;

                // we can be certain the ray has intersected the box when the furthest entry
                // is closer to the camera than the closes exit.
                if (entry < exit)
                {
                    return float4(0, 1, 0, 1);
                }

                // pixels that dont intersect are lef alone
                return originalColour;
            }
            ENDCG
        }
    }
}
