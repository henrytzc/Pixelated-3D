Shader "Custom/EdgeDetectionPostProcess"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        _LightIntensity ("Light Intensity", Float) = 1.25
        _LineAlpha ("Line Alpha", Range(0.0, 1.0)) = 0.7
        _UseLighting ("Use Lighting", Float) = 1.0
        _LineHighlight ("Line Highlight", Range(0.0, 1.0)) = 0.2
        _LineShadow ("Line Shadow", Range(0.0, 1.0)) = 0.55
        _EdgeThreshold ("Edge Threshold", Range(0.0, 1.0)) = 0.25
        _NormalThreshold ("Normal Threshold", Range(0.0, 1.0)) = 0.2
    }

    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "EdgeDetectionPass"
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 screenUV : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            CBUFFER_START(UnityPerMaterial)
                float _LightIntensity;
                float _LineAlpha;
                float _UseLighting;
                float _LineHighlight;
                float _LineShadow;
                float _EdgeThreshold;
                float _NormalThreshold;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                output.screenUV = input.uv;
                
                return output;
            }

            float GetLinearDepth(float2 uv, float mask)
            {
                float depth = SampleSceneDepth(uv) * mask;
                return LinearEyeDepth(depth, _ZBufferParams);
            }

            float3 GetNormal(float2 uv, float mask)
            {
                float3 normal = SampleSceneNormals(uv);
                return normal * mask;
            }

            float NormalEdgeIndicator(float3 normalEdgeBias, float3 normal, float3 neighborNormal, float depthDifference)
            {
                float normalDifference = dot(normal - neighborNormal, normalEdgeBias);
                float normalIndicator = saturate(smoothstep(-0.01, 0.01, normalDifference));
                float depthIndicator = saturate(sign(depthDifference * 0.25 + 0.0025));
                return (1.0 - dot(normal, neighborNormal)) * depthIndicator * normalIndicator;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                
                float2 texelSize = 1.0 / _ScreenParams.xy;
                
                // UV offsets for sampling neighboring pixels
                float2 UVOffsets[4];
                UVOffsets[0] = input.screenUV + float2(0.0, -1.0) * texelSize;
                UVOffsets[1] = input.screenUV + float2(0.0, 1.0) * texelSize;
                UVOffsets[2] = input.screenUV + float2(1.0, 0.0) * texelSize;
                UVOffsets[3] = input.screenUV + float2(-1.0, 0.0) * texelSize;

                // Using alpha channel to mask objects (roughness in URP)
                float outlineMask = 1.0; // Default to 1, can be modified based on material properties
                
                // Edge detection with Depth
                float depthDifference = 0.0;
                float invDepthDifference = 0.5;
                float depth = GetLinearDepth(input.screenUV, outlineMask);

                for (int i = 0; i < 4; i++)
                {
                    float dOff = GetLinearDepth(UVOffsets[i], outlineMask);
                    depthDifference += saturate(dOff - depth);
                    invDepthDifference += depth - dOff;
                }
                
                invDepthDifference = saturate(invDepthDifference);
                invDepthDifference = saturate(smoothstep(0.9, 0.9, invDepthDifference) * 10.0);
                depthDifference = smoothstep(_EdgeThreshold, _EdgeThreshold + 0.05, depthDifference);

                // Edge detection with Normals
                float normalDifference = 0.0;
                float3 normalEdgeBias = float3(1.0, 1.0, 1.0);
                float3 normal = GetNormal(input.screenUV, outlineMask);

                for (int i = 0; i < 4; i++)
                {
                    float3 nOff = GetNormal(UVOffsets[i], outlineMask);
                    normalDifference += NormalEdgeIndicator(normalEdgeBias, normal, nOff, depthDifference);
                }
                
                normalDifference = smoothstep(_NormalThreshold, _NormalThreshold, normalDifference);
                normalDifference = saturate(normalDifference - invDepthDifference);

                // Sample the main texture
                half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                float lineMask = saturate(lerp(0.1, _LineAlpha, (depthDifference + normalDifference * 5.0)));

                // Apply lighting effects
                if (_UseLighting > 0.5)
                {
                    // Get main light
                    Light mainLight = GetMainLight();
                    float3 lightDir = mainLight.direction;
                    float3 lightColor = mainLight.color;
                    
                    float dotNL = dot(normal, lightDir);
                    dotNL = pow(abs(dotNL), 2.5);
                    dotNL = saturate(dotNL);
                    
                    color.rgb = lerp(float3(1.0, 1.0, 1.0), dotNL * lightColor * _LightIntensity, lineMask);
                }
                else
                {
                    color.rgb += saturate(normalDifference - depthDifference) * _LineHighlight;
                    color.rgb -= color.rgb * depthDifference * _LineShadow;
                }

                return color;
            }
            ENDHLSL
        }
    }
} 