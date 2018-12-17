Shader "Custom/ReflectionTest Standard"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_Glossiness("Smoothness", Range(0,1)) = 0.5
		_Metallic("Metallic", Range(0,1)) = 0.0 
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma multi_compile_fwdbase
			#include "HLSLSupport.cginc"
			#include "UnityShaderVariables.cginc"
			#include "UnityShaderUtilities.cginc"
			
			//#define UNITY_PASS_FORWARDBASE
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "UnityPBSLighting.cginc"
			#include "AutoLight.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				UNITY_POSITION(pos);
				float2 pack0 : TEXCOORD0;
				float3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				float4 lmap : TEXCOORD3;
				UNITY_SHADOW_COORDS(4)
					UNITY_FOG_COORDS(5)
#ifndef LIGHTMAP_ON
#if UNITY_SHOULD_SAMPLE_SH
					half3 sh : TEXCOORD6;
#endif
#endif
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			half _Glossiness;
			half _Metallic;
			fixed4 _Color;

			sampler2D _ThetaTex;

			struct Input
			{
				float2 uv_MainTex;
			};

			void surf(Input IN, inout SurfaceOutputStandard o)
			{
				fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
				o.Albedo = c.rgb;
				o.Metallic = _Metallic;
				o.Smoothness = _Glossiness;
				o.Alpha = c.a;
			}

			v2f vert (appdata_full v)
			{
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f, o);

				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.pos = UnityObjectToClipPos(v.vertex);
				o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				float3 worldNormal = UnityObjectToWorldNormal(v.normal);
				o.worldPos = worldPos;
				o.worldNormal = worldNormal;

#ifdef DYNAMICLIGHTMAP_ON
				o.lmap.zw = v.texcoord2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif

#ifdef LIGHTMAP_ON
				o.lmap.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
#endif

#ifndef LIGHTMAP_ON
#if UNITY_SHOULD_SAMPLE_SH && !UNITY_SAMPLE_FULL_SH_PER_PIXEL
				o.sh = 0;
#ifdef VERTEXLIGHT_ON
				o.sh += Shade4PointLights(
					unity_4LightPosX0,
					unity_4LightPosY0,
					unity_4LightPosZ0,
					unity_LightColor[0].rgb,
					unity_LightColor[1].rgb,
					unity_LightColor[2].rgb,
					unity_LightColor[3].rgb,
					unity_4LightAtten0,
					worldPos,
					worldNormal);
#endif
				o.sh = ShadeSHPerVertex(worldNormal, o.sh);
#endif
#endif

				UNITY_TRANSFER_SHADOW(o, v.texcoord1.xy);
				UNITY_TRANSFER_FOG(o, o.pos);
				return o;
			}

			inline float2 ToRadialCoords(float3 dir)
			{
				float3 normalizedCoords = normalize(dir);
				float latitude = acos(normalizedCoords.y);
				float longitude = atan2(normalizedCoords.z, normalizedCoords.x);
				float2 sphereCoords = float2(longitude, latitude) * float2(0.5 / UNITY_PI, 1.0 / UNITY_PI);
				return float2(0.5, 1.0) - sphereCoords;
			}

			half3 Unity_GlossyEnvironmentCustom(sampler2D tex, half4 hdr, Unity_GlossyEnvironmentData glossIn)
			{
				// Reflection
				float2 tc = ToRadialCoords(glossIn.reflUVW);
				if (tc.x > 1.0)
					return half4(0, 0, 0, 1);
				tc.x = fmod(tc.x, 1);

				half perceptualRoughness = glossIn.roughness /* perceptualRoughness */;
				perceptualRoughness = perceptualRoughness * (1.7 - 0.7*perceptualRoughness);

				half mip = perceptualRoughnessToMipmapLevel(perceptualRoughness);
				half4 rgbm = tex2Dlod(_ThetaTex, float4(tc, 0, mip));

				return DecodeHDR(rgbm, hdr);
			}

			inline half3 UnityGI_IndirectSpecularCustom(UnityGIInput data, half occlusion, Unity_GlossyEnvironmentData glossIn)
			{
				half3 specular;

#ifdef UNITY_SPECCUBE_BOX_PROJECTION
				// we will tweak reflUVW in glossIn directly (as we pass it to Unity_GlossyEnvironment twice for probe0 and probe1), so keep original to pass into BoxProjectedCubemapDirection
				half3 originalReflUVW = glossIn.reflUVW;
				glossIn.reflUVW = BoxProjectedCubemapDirection(originalReflUVW, data.worldPos, data.probePosition[0], data.boxMin[0], data.boxMax[0]);
#endif

#ifdef _GLOSSYREFLECTIONS_OFF
				specular = unity_IndirectSpecColor.rgb;
#else
				//half3 env0 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), data.probeHDR[0], glossIn);
				half3 env0 = Unity_GlossyEnvironmentCustom(_ThetaTex, data.probeHDR[0], glossIn);

#ifdef UNITY_SPECCUBE_BLENDING
				const float kBlendFactor = 0.99999;
				float blendLerp = data.boxMin[0].w;
				UNITY_BRANCH
					if (blendLerp < kBlendFactor)
					{
#ifdef UNITY_SPECCUBE_BOX_PROJECTION
						glossIn.reflUVW = BoxProjectedCubemapDirection(originalReflUVW, data.worldPos, data.probePosition[1], data.boxMin[1], data.boxMax[1]);
#endif

						half3 env1 = Unity_GlossyEnvironmentCustom(_ThetaTex, data.probeHDR[1], glossIn);
						specular = lerp(env1, env0, blendLerp);
					}
					else
					{
						specular = env0;
					}
#else
				specular = env0;
#endif
#endif

				return specular * occlusion;
			}

			inline UnityGI UnityGlobalIlluminationCustom(UnityGIInput data, half occlusion, half3 normalWorld, Unity_GlossyEnvironmentData glossIn)
			{
				UnityGI o_gi = UnityGI_Base(data, occlusion, normalWorld);
				o_gi.indirect.specular = UnityGI_IndirectSpecularCustom(data, occlusion, glossIn);
				return o_gi;
			}

			inline void LightingStandard_GI_Custom(
				SurfaceOutputStandard s,
				UnityGIInput data,
				inout UnityGI gi)
			{
#if defined(UNITY_PASS_DEFERRED) && UNITY_ENABLE_REFLECTION_BUFFERS
				gi = UnityGlobalIllumination(data, s.Occlusion, s.Normal);
#else
				Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(s.Smoothness, data.worldViewDir, s.Normal, lerp(unity_ColorSpaceDielectricSpec.rgb, s.Albedo, s.Metallic));
				gi = UnityGlobalIlluminationCustom(data, s.Occlusion, s.Normal, g);
#endif
			}

			fixed4 frag (v2f IN) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(IN);

				float3 worldPos = IN.worldPos;
				float3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));

#ifndef USING_DIRECTIONAL_LIGHT
				fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
#else
				fixed3 lightDir = _WorldSpaceLightPos0.xyz;
#endif

				Input surfIN;
				UNITY_INITIALIZE_OUTPUT(Input, surfIN);
				surfIN.uv_MainTex.x = 1.0;
				surfIN.uv_MainTex = IN.pack0.xy;

				SurfaceOutputStandard o;
				UNITY_INITIALIZE_OUTPUT(SurfaceOutputStandard, o);
				o.Albedo = 0.0;
				o.Emission = 0.0;
				o.Alpha = 0.0;
				o.Occlusion = 1.0;
				o.Normal = IN.worldNormal;

				surf(surfIN, o);

				UNITY_LIGHT_ATTENUATION(atten, IN, worldPos)

				fixed4 c = 0;

				UnityGI gi;
				UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
				gi.indirect.diffuse = 0;
				gi.indirect.specular = 0;
				gi.light.color = _LightColor0.rgb;
				gi.light.dir = lightDir;

				UnityGIInput giInput;
				UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
				giInput.light = gi.light;
				giInput.worldPos = worldPos;
				giInput.worldViewDir = worldViewDir;
				giInput.atten = atten;

#if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
				giInput.lightmapUV = IN.lmap;
#else
				giInput.lightmapUV = 0.0;
#endif

#if UNITY_SHOULD_SAMPLE_SH && !UNITY_SAMPLE_FULL_SH_PER_PIXEL
				giInput.ambient = IN.sh;
#else
				giInput.ambient.rgb = 0.0;
#endif

				giInput.probeHDR[0] = unity_SpecCube0_HDR;
				giInput.probeHDR[1] = unity_SpecCube1_HDR;

#if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
				giInput.boxMin[0] = unity_SpecCube0_BoxMin;
#endif

#ifdef UNITY_SPECCUBE_BOX_PROJECTION
				giInput.boxMax[0] = unity_SpecCube0_BoxMax;
				giInput.probePosition[0] = unity_SpecCube0_ProbePosition;
				giInput.boxMax[1] = unity_SpecCube1_BoxMax;
				giInput.boxMin[1] = unity_SpecCube1_BoxMin;
				giInput.probePosition[1] = unity_SpecCube1_ProbePosition;
#endif

				LightingStandard_GI_Custom(o, giInput, gi);
				c += LightingStandard(o, worldViewDir, gi);

				UNITY_APPLY_FOG(IN.fogCoord, c);
				UNITY_OPAQUE_ALPHA(c.a);

				return c;
			}
			ENDCG
		}

		Pass
		{

		Name "FORWARD"
		Tags { "LightMode" = "ForwardAdd" }
		ZWrite Off Blend One One

		CGPROGRAM
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma target 3.0
		#pragma multi_compile_instancing
		#pragma multi_compile_fog
		#pragma skip_variants INSTANCING_ON
		#pragma multi_compile_fwdadd_fullshadows
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#include "UnityShaderUtilities.cginc"

		//#define UNITY_PASS_FORWARDADD
		#include "UnityCG.cginc"
		#include "Lighting.cginc"
		#include "UnityPBSLighting.cginc"
		#include "AutoLight.cginc"

		sampler2D _MainTex;
		float4 _MainTex_ST;
		half _Glossiness;
		half _Metallic;
		fixed4 _Color;

		struct Input
		{
			float2 uv_MainTex;
		};

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}

		struct v2f_surf
		{
			UNITY_POSITION(pos);
			float2 pack0 : TEXCOORD0;
			float3 worldNormal : TEXCOORD1;
			float3 worldPos : TEXCOORD2;
			UNITY_SHADOW_COORDS(3)
			UNITY_FOG_COORDS(4)
			UNITY_VERTEX_INPUT_INSTANCE_ID
			UNITY_VERTEX_OUTPUT_STEREO
		};

		v2f_surf vert_surf(appdata_full v)
		{
			UNITY_SETUP_INSTANCE_ID(v);
			v2f_surf o;
			UNITY_INITIALIZE_OUTPUT(v2f_surf,o);
			UNITY_TRANSFER_INSTANCE_ID(v,o);
			UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
			o.pos = UnityObjectToClipPos(v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
			o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
			o.worldNormal = UnityObjectToWorldNormal(v.normal);

			UNITY_TRANSFER_SHADOW(o,v.texcoord1.xy);
			UNITY_TRANSFER_FOG(o,o.pos);
			return o;
		}

		fixed4 frag_surf(v2f_surf IN) : SV_Target
		{
			UNITY_SETUP_INSTANCE_ID(IN);

			Input surfIN;
			UNITY_INITIALIZE_OUTPUT(Input,surfIN);
			surfIN.uv_MainTex.x = 1.0;
			surfIN.uv_MainTex = IN.pack0.xy;

			float3 worldPos = IN.worldPos;
			float3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
		#ifndef USING_DIRECTIONAL_LIGHT
			fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
		#else
			fixed3 lightDir = _WorldSpaceLightPos0.xyz;
		#endif

			SurfaceOutputStandard o;
			UNITY_INITIALIZE_OUTPUT(SurfaceOutputStandard, o);
			o.Albedo = 0.0;
			o.Emission = 0.0;
			o.Alpha = 0.0;
			o.Occlusion = 1.0;
			o.Normal = IN.worldNormal;

			surf(surfIN, o);
			UNITY_LIGHT_ATTENUATION(atten, IN, worldPos)
			fixed4 c = 0;

			UnityGI gi;
			UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
			gi.indirect.diffuse = 0;
			gi.indirect.specular = 0;
			gi.light.color = _LightColor0.rgb;
			gi.light.dir = lightDir;
			gi.light.color *= atten;

			c += LightingStandard(o, worldViewDir, gi);
			c.a = 0.0;

			UNITY_APPLY_FOG(IN.fogCoord, c);
			UNITY_OPAQUE_ALPHA(c.a);

			return c;
		}

		ENDCG

		}
	}
}
