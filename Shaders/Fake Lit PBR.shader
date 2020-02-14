﻿Shader "KVY/Fake Lit PBR"
{
    Properties
    {
        _MainTex ("BaseColor Map", 2D) = "white" {}
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _AOIntensity ("AO Intensity", Range(0, 2)) = 1
        _AOMap ("AO Map", 2D) = "white" {}
        _Metalness ("Metalness Intensity", Range(0, 1)) = 0
        _MetalnessMap ("Metalness Map", 2D) = "white" {}
        _Roughness ("Roughness Intensity", Range(0, 1)) = 1 
        _RoughnessMap ("Roughness Map", 2D) = "white" {}
        _Emissive("Emissive Intensity", Range(0, 5)) = 1
        _EmissiveMap ("Emissive Map", 2D) = "black" {}
        //_SkyBox ("Cubemap", CUBE) = "" {} 
    }
    SubShader
    {
        Pass
        {
            CGPROGRAM 
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "FunctionLib.cginc"

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                half3 worldNormal : TEXCOORD2;

                half3x3 tangentSpace : TEXCOORD3;
                // tangent Space = { {tangent.x [0][0], bitangent.x [0][1], normal.x[0][2]},
                //                   {tangent.y [1][0], bitangent.y [1][1], normal.y[1][2]},
                //                   {tangent.z [2][0], bitangent.z [2][1], normal.z[2][2]} }
                half3 normal : NORMAL;
            };

            samplerCUBE _SkyBox;
            sampler2D _MainTex, _AOMap, _BumpMap, _MetalnessMap, _RoughnessMap, _EmissiveMap;
            half _Metalness, _Roughness, _AOIntensity, _Emissive, _SunIntensity;
            fixed3 _SunColor;
            float3 _Sun;

            v2f vert(float4 vertex : POSITION, float3 normal : NORMAL, float2 uv : TEXCOORD0, float4 tangent : TANGENT)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(vertex);
                o.uv = uv;

                o.worldPos = mul(unity_ObjectToWorld, vertex);
                o.worldNormal = UnityObjectToWorldNormal(normal);
                o.normal = o.worldNormal;

                half3 worldTangent = UnityObjectToWorldDir(tangent);
                half3 worldBitangent = cross(o.worldNormal, worldTangent) * tangent.w * unity_WorldTransformParams.w;

                o.tangentSpace[0] = half3(worldTangent.x, worldBitangent.x, o.worldNormal.x);
                o.tangentSpace[1] = half3(worldTangent.y, worldBitangent.y, o.worldNormal.y);
                o.tangentSpace[2] = half3(worldTangent.z, worldBitangent.z, o.worldNormal.z);

                return o;
            }

            fixed3 frag(v2f i) : SV_TARGET
            {
                half3 tangentNormal = UnpackNormal(tex2D(_BumpMap, i.uv));
                i.worldNormal = half3
                                    (
                                    dot(i.tangentSpace[0], tangentNormal),
                                    dot(i.tangentSpace[1], tangentNormal),
                                    dot(i.tangentSpace[2], tangentNormal)
                                    );

                fixed3 col;
                col = tex2D(_MainTex, i.uv);
                col *= lerp(1, tex2D(_AOMap, i.uv), _AOIntensity);

                half3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                half3 worldReflect = reflect(-worldViewDir, i.worldNormal);
                //half4 sky = UNITY_SAMPLE_TEXCUBE(_SkyBox, worldReflect); // sample the default reflection cubemap, using the reflection vector
                half4 sky = texCUBE(_SkyBox, worldReflect);

                fixed3 emis = tex2D(_EmissiveMap, i.uv) * _Emissive;

                fixed3 light = remap(
                    dot(normalize(i.worldNormal), normalize(_Sun)), -1, 1, 0, 1
                    )
                    * _SunColor * _SunIntensity;

                fixed3 metalrough = lerp(
                    col * lerp(1, sky, _Metalness * tex2D(_MetalnessMap, i.uv)), 
                    sky, 
                    ((1-tex2D(_RoughnessMap, i.uv)) * _Roughness * 0.5) 
                    );

                return metalrough * light + emis * _Emissive;  
            }
            ENDCG
        }
    }
}