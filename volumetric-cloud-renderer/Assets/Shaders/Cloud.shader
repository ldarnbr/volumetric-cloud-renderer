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
            };

            VertexOutput VertexProgram (VertexInput input)
            {
                VertexOutput output;
                // converts the vertex position from the object to surface space
                output.screenPosition = UnityObjectToClipPos(input.vertex);
                output.uv = input.uv;
                return output;
            }

            // the scene from Graphics.Blit as a 2D texture. Links to the _MainTex in the inspector
            sampler2D _MainTex;

            // DOCS:
            // https://docs.unity3d.com/2020.1/Documentation/Manual/SL-ShaderSemantics.html
            float4 FragmentProgram (VertexOutput input) : SV_Target
            {
                // gets the original colour in the scene for this pixel
                float4 originalColour = tex2D(_MainTex, input.uv);

                // return green colour
                return float4(0, 1, 0, 1);
            }


            ENDCG
        }
    }
}
