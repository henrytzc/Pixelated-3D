Shader "Hidden/Custom/EdgeDetection"
{
    Properties{
        _EdgeColor("Edge Color", Color) = (0,0,0,1)
        _BackgroundBlend("Background Blend (0=edge only,1=overlay)", Range(0,1)) = 1
        _Threshold("Luma Threshold", Range(0,1)) = 0.2
        _SampleScale("Sample Scale (px)", Range(0.5,3)) = 1
        _DepthSens("Depth Sensitivity", Range(0,5)) = 0
        _NormalSens("Normal Sensitivity", Range(0,5)) = 0
    }
    SubShader{
        Tags{ "RenderPipeline"="UniversalRenderPipeline" }

        Pass{
            Name "EdgeDetection"
            ZTest Always ZWrite Off Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // 由 RendererFeature/Blitter 提供
            TEXTURE2D_X(_BlitTexture);           SAMPLER(sampler_BlitTexture);
            float4 _BlitTexture_TexelSize; // x=1/w, y=1/h

            // 選配：深度/法線（要在渲染器開啟）
            TEXTURE2D_X_FLOAT(_CameraDepthTexture);    SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D_X_FLOAT(_CameraNormalsTexture);  SAMPLER(sampler_CameraNormalsTexture);

            float4 _EdgeColor;
            float _BackgroundBlend, _Threshold, _SampleScale, _DepthSens, _NormalSens;

            struct FS_IN { float4 posCS: SV_Position; float2 uv: TEXCOORD0; };

            // 自製全螢幕三角形（不需要 Fullscreen.hlsl）
            FS_IN Vert(uint id : SV_VertexID)
            {
                FS_IN o;
                // 大三角形覆蓋整個畫面：(-1,-1), (-1,3), (3,-1)
                float2 pos[3] = { float2(-1,-1), float2(-1,3), float2(3,-1) };
                float2 uv [3] = { float2( 0, 0), float2( 0,2), float2(2, 0) };
                o.posCS = float4(pos[id], 0, 1);
                o.uv    = uv[id];
                return o;
            }

            float Luma(float3 c){ return dot(c, float3(0.299,0.587,0.114)); }

            float SobelLuma(float2 uv){
                float2 px = _BlitTexture_TexelSize.xy * _SampleScale;
                float3 s00 = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, uv + float2(-px.x, -px.y)).rgb;
                float3 s10 = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, uv + float2( 0,    -px.y)).rgb;
                float3 s20 = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, uv + float2( px.x, -px.y)).rgb;
                float3 s01 = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, uv + float2(-px.x,  0)).rgb;
                float3 s21 = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, uv + float2( px.x,  0)).rgb;
                float3 s02 = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, uv + float2(-px.x,  px.y)).rgb;
                float3 s12 = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, uv + float2( 0,     px.y)).rgb;
                float3 s22 = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, uv + float2( px.x,  px.y)).rgb;

                float gx = Luma(s20)+2*Luma(s21)+Luma(s22) - (Luma(s00)+2*Luma(s01)+Luma(s02));
                float gy = Luma(s02)+2*Luma(s12)+Luma(s22) - (Luma(s00)+2*Luma(s10)+Luma(s20));
                return sqrt(gx*gx + gy*gy);
            }

            float DepthEdge(float2 uv){
                if (_DepthSens<=0) return 0;
                float2 px = _BlitTexture_TexelSize.xy * _SampleScale;
                float c = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
                float r = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, uv+float2(px.x,0)).r;
                float u = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, uv+float2(0,-px.y)).r;
                return abs(r-c)+abs(u-c);
            }

            float NormalEdge(float2 uv){
                if (_NormalSens<=0) return 0;
                float2 px = _BlitTexture_TexelSize.xy * _SampleScale;
                float3 c = SAMPLE_TEXTURE2D_X(_CameraNormalsTexture, sampler_CameraNormalsTexture, uv).xyz*2-1;
                float3 r = SAMPLE_TEXTURE2D_X(_CameraNormalsTexture, sampler_CameraNormalsTexture, uv+float2(px.x,0)).xyz*2-1;
                float3 u = SAMPLE_TEXTURE2D_X(_CameraNormalsTexture, sampler_CameraNormalsTexture, uv+float2(0,-px.y)).xyz*2-1;
                return saturate(length(r-c)+length(u-c));
            }

            float4 Frag(FS_IN i):SV_Target
            {
                float4 src = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv);
                float eCol = SobelLuma(i.uv);
                float eDep = DepthEdge(i.uv) * _DepthSens;
                float eNor = NormalEdge(i.uv) * _NormalSens;

                float edge = saturate(eCol + eDep + eNor);
                edge = step(_Threshold, edge);

                float4 edgeCol = float4(_EdgeColor.rgb, 1);
                // 0=edge only，1=把邊線覆蓋到原畫面
                float4 mixed = lerp(edgeCol*edge, src, _BackgroundBlend);
                return mixed;
            }
            ENDHLSL
        }
    }
    FallBack Off
}
