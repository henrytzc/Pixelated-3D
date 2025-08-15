Shader "Custom/Toon"
{
    Properties
    {
        [MainTexture]_BaseMap("Base Map", 2D) = "white" {}
        [MainColor]_BaseColor("Base Color", Color) = (1,1,1,1)
        _Steps("Color Steps", Range(1,16)) = 4
        _MinLight("Shadow Floor", Range(0,1)) = 0.1
        _SmoothWidth("Band Antialiasing", Range(0,1)) = 0.25

        // === Per-darkening-step HSV (legacy/simple mode) ===
        [Toggle]_EnableHSVShift("Enable HSV Shift Per Dark Step", Float) = 0
        _HueTargetDeg("Hue Target (deg)", Range(0,360)) = 240
        _HueTowardPerStep("Hue Toward Target / Step (deg)", Range(0,180)) = 20
        _SatPerStepPct("Saturation Δ / Step (%)", Range(-100,100)) = 10
        _ValPerStepPct("Value Δ / Step (%)", Range(-100,100)) = -20

        // === Band profile (dark/bright sides around a base band) ===
        [Toggle]_EnableBandProfile("Enable Band Profile", Float) = 1
        _BaseBandIndex("Base Band Index", Range(0,16)) = 2
        _HueAwayPerStep("Hue Away / Step (deg)", Range(0,180)) = 20
        _SatPerStepDarkPct("Sat Δ Dark / Step (%)", Range(-100,100)) = 10
        _ValPerStepDarkPct("Val Δ Dark / Step (%)", Range(-100,100)) = -20
        _SatPerStepBrightPct("Sat Δ Bright / Step (%)", Range(-100,100)) = -10
        _ValPerStepBrightPct("Val Δ Bright / Step (%)", Range(-100,100)) = 20
        
        [ToggleUI] _ReceiveShadows("Receive Shadows", Float) = 1.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" "UniversalMaterialType"="Lit" "RenderPipeline"="UniversalPipeline" }
        LOD 200
        Cull Back
        ZWrite On
        ZTest LEqual
        Blend Off

        Pass
        {
            Name "ForwardLit"
            Tags{ "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // URP lighting & features
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseMap_ST;
                float  _Steps;
                float  _MinLight;
                float  _SmoothWidth;
                float  _EnableHSVShift;
                float  _HueTargetDeg;
                float  _HueTowardPerStep;
                float  _SatPerStepPct;
                float  _ValPerStepPct;

                // Band profile controls
                float  _EnableBandProfile;   // 0/1
                float  _BaseBandIndex;       // base band index (0 = darkest)
                float  _HueAwayPerStep;      // deg
                float  _SatPerStepDarkPct;   // +10
                float  _ValPerStepDarkPct;   // -20
                float  _SatPerStepBrightPct; // -10
                float  _ValPerStepBrightPct; // +20
                float  _ReceiveShadows;
            CBUFFER_END

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_Position;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float2 uv         : TEXCOORD2;
                float4 fogCoord   : TEXCOORD3;
                float4 shadowCoord : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert (Attributes v)
            {
                Varyings o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.normalWS   = TransformObjectToWorldNormal(v.normalOS);
                o.positionCS = TransformWorldToHClip(o.positionWS);
                o.uv         = TRANSFORM_TEX(v.uv, _BaseMap);
                o.fogCoord   = ComputeFogFactor(o.positionCS.z);
                #ifdef _MAIN_LIGHT_SHADOWS
                o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
                #else
                o.shadowCoord = float4(0, 0, 0, 0);
                #endif
                return o;
            }

            // Quantize a 0..1 value into N bands with optional AA using fwidth
            inline half Quantize01(half v, half steps, half aaWidth)
            {
                v = saturate(v);
                steps = max(1.0h, steps);
                if (aaWidth > 0.0h)
                {
                    half w = fwidth(v) * aaWidth * 1.5h;
                    half accum = 0.0h;
                    [unroll(16)] for (int i = 1; i <= 16; i++)
                    {
                        if (i > (int)steps) break;
                        half t = (half)i / steps; // threshold in 0..1
                        accum += smoothstep(t - w, t + w, v);
                    }
                    return accum / steps; // mapped back to 0..1
                }
                return floor(v * steps) / steps;
            }

            // Helpers for HSV <-> RGB using 0..1 ranges for H,S,V (H wraps)
            inline half3 RGBtoHSV(half3 c)
            {
                half4 K = half4(0.0h, -1.0h/3.0h, 2.0h/3.0h, -1.0h);
                half4 p = (c.g < c.b) ? half4(c.bg, K.wz) : half4(c.gb, K.xy);
                half4 q = (c.r < p.x) ? half4(p.xyw, c.r) : half4(c.r, p.yzx);
                half d = q.x - min(q.w, q.y);
                half e = 1.0e-4h;
                half h = abs(q.z + (q.w - q.y) / (6.0h * d + e));
                half s = d / (q.x + e);
                half vVal = q.x;
                return half3(h, s, vVal);
            }

            inline half3 HSVtoRGB(half3 hsv)
            {
                half h = hsv.x; // 0..1
                half s = saturate(hsv.y);
                half v = saturate(hsv.z);
                half3 rgb = half3(v, v, v);
                if (s <= 1e-5h) return rgb; // gray
                h = frac(h) * 6.0h;
                int hi = (int)floor(h);
                half f = h - hi;
                half p = v * (1.0h - s);
                half q = v * (1.0h - s * f);
                half t = v * (1.0h - s * (1.0h - f));
                if (hi == 0) rgb = half3(v, t, p);
                else if (hi == 1) rgb = half3(q, v, p);
                else if (hi == 2) rgb = half3(p, v, t);
                else if (hi == 3) rgb = half3(p, q, v);
                else if (hi == 4) rgb = half3(t, p, v);
                else rgb = half3(v, p, q);
                return rgb;
            }

            inline half shortestHueDelta01(half h, half t)
            {
                // both in 0..1, return signed delta in -0.5..0.5 representing shortest path
                half d = t - h;
                d = d - floor(d + 0.5h); // wrap to [-0.5, 0.5)
                return d;
            }

            inline half3 ApplyHSVBandProfile(half3 rgb, half bandIndex)
            {
                if (_EnableBandProfile < 0.5h) return rgb;
                half3 hsv = RGBtoHSV(rgb);
                half targetH = (_HueTargetDeg / 360.0h);

                half k = bandIndex - (half)_BaseBandIndex; // negative = darker, positive = brighter
                if (abs(k) < 0.5h) return rgb; // base band: no change

                half absK = abs(k);
                half delta = shortestHueDelta01(hsv.x, targetH);

                if (k < 0.0h)
                {
                    // toward target for dark side
                    half maxMove = (_HueTowardPerStep / 360.0h) * absK;
                    half move = clamp(delta, -maxMove, maxMove);
                    hsv.x = frac(hsv.x + move);

                    hsv.y = saturate(hsv.y + (_SatPerStepDarkPct * 0.01h) * absK);
                    hsv.z = saturate(hsv.z + (_ValPerStepDarkPct * 0.01h) * absK);
                }
                else
                {
                    // away from target for bright side
                    half maxMove = (_HueAwayPerStep / 360.0h) * absK;
                    half move = clamp(-delta, -maxMove, maxMove);
                    hsv.x = frac(hsv.x + move);

                    hsv.y = saturate(hsv.y + (_SatPerStepBrightPct * 0.01h) * absK);
                    hsv.z = saturate(hsv.z + (_ValPerStepBrightPct * 0.01h) * absK);
                }

                return HSVtoRGB(hsv);
            }

            half4 frag (Varyings i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);

                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv) * _BaseColor;

                half3 N = normalize(i.normalWS);

                #ifdef _MAIN_LIGHT_SHADOWS
                #ifndef _RECEIVE_SHADOWS_OFF
                Light mainLight = GetMainLight(i.shadowCoord);
                #else
                Light mainLight = GetMainLight();
                #endif
                #else
                Light mainLight = GetMainLight();
                #endif
                half NdotL = saturate(dot(N, mainLight.direction));
                half mainLit = NdotL * mainLight.shadowAttenuation * mainLight.distanceAttenuation;

                #ifdef _ADDITIONAL_LIGHTS
                uint addCount = GetAdditionalLightsCount();
                [loop] for (uint li = 0u; li < addCount; li++)
                {
                    Light l = GetAdditionalLight(li, i.positionWS);
                    half ndl = saturate(dot(N, l.direction));
                    mainLit += ndl * l.shadowAttenuation * l.distanceAttenuation;
                }
                #endif

                mainLit = max(mainLit, (half)_MinLight);

                // Quantized band value (0..1) for lighting contribution
                half stepsH = (half)max(1.0, _Steps);
                half bands = Quantize01(mainLit, stepsH, (half)_SmoothWidth);

                // Discrete band index 0..steps-1 from quantized value
                half bandIndex = floor(saturate(bands) * stepsH);
                bandIndex = min(bandIndex, stepsH - 1.0h);

                // Base color after banded lighting
                half3 litColor = albedo.rgb * bands;

                // Legacy/simple dark-step mode (optional)
                if (_EnableHSVShift > 0.5)
                {
                    half3 hsv = RGBtoHSV(litColor);
                    half targetH = (_HueTargetDeg / 360.0h);
                    // number of dark steps from brightest
                    half kDark = (stepsH - 1.0h) - min(floor(saturate(mainLit) * stepsH), stepsH - 1.0h);
                    half perStep01 = (_HueTowardPerStep / 360.0h);
                    half delta = shortestHueDelta01(hsv.x, targetH);
                    half maxMove = perStep01 * kDark;
                    half move = clamp(delta, -maxMove, maxMove);
                    hsv.x = frac(hsv.x + move);
                    hsv.y = saturate(hsv.y + (_SatPerStepPct * 0.01h) * kDark);
                    hsv.z = saturate(hsv.z + (_ValPerStepPct * 0.01h) * kDark);
                    litColor = HSVtoRGB(hsv);
                }

                // Apply band profile (dark/bright symmetric around base)
                litColor = ApplyHSVBandProfile(litColor, bandIndex);

                // Fog
                litColor = MixFog(litColor, i.fogCoord);

                return half4(litColor, albedo.a);
            }
            ENDHLSL
        }

        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
    }

    FallBack Off
}
