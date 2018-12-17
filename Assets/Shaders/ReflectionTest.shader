Shader "Custom/ReflectionTest"
{
	SubShader
	{
		Tags { "RenderType" = "Opaque" }

		Pass
		{
			CGPROGRAM
		   #pragma vertex vert
		   #pragma fragment frag

		   #include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex	: POSITION;
				float4 normal	: NORMAL;
				float2 texcoord	: TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex		: SV_POSITION;
				float3 worldPos		: TEXCOORD0;
				float3 worldNormal	: TEXCOORD1;
				float3 pos			: TEXCOORD2;
				float2 uv			: TEXCOORD3;
			};

			sampler2D _ThetaTex;

			inline float2 ToRadialCoords(float3 dir)
			{
				float3 normalizedCoords = normalize(dir);
				float latitude = acos(normalizedCoords.y);							// 緯度
				float longitude = atan2(normalizedCoords.z, normalizedCoords.x);	// 経度
				float2 sphereCoords = float2(longitude, latitude) * float2(0.5 / UNITY_PI, 1.0 / UNITY_PI);	// UVに変換
				return float2(0.5, 1.0) - sphereCoords;
			}

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				o.uv = v.texcoord;

				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				half3 worldViewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
				half3 reflDir = reflect(-worldViewDir, i.worldNormal);

				// Reflection
				float2 tc = ToRadialCoords(reflDir);
				if (tc.x > 1.0)
					return half4(0, 0, 0, 1);

				tc.x = fmod(tc.x, 1);
				
				half4 refColor = tex2D(_ThetaTex, tc);
				
				return refColor;
			}
			ENDCG
		}
	}
}