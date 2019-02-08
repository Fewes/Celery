#ifndef CELERY_INCLUDED
#define CELERY_INCLUDED

	#include "HLSLSupport.cginc"
	#include "UnityShaderVariables.cginc"
	#include "UnityShaderUtilities.cginc"
	#include "UnityCG.cginc"
	#include "Lighting.cginc"
	#include "AutoLight.cginc"
	#include "HSV.cginc"

	// #define INTERNAL_DATA
	// #define WorldReflectionVector(data,normal) data.worldRefl
	// #define WorldNormalVector(data,normal) normal

	struct SurfaceOutputCel
	{
		fixed3 Albedo;
		fixed3 Normal;
		fixed3 Emission;
		half   Specular;
		fixed  Gloss;
		fixed  Rim;
		fixed  Alpha;
	};

	sampler2D _Ramp;
	float _Edge;
	float _SpecIntensity;
	float _SpecPower;

	half4 LightingCel (SurfaceOutputCel s, half3 lightDir, half3 viewDir, half atten)
	{
		half NdotL = dot(s.Normal, lightDir);
		half diff = max(NdotL, 0);

		diff = smoothstep(_Edge, 1 - _Edge, diff);

		half3 h = normalize (lightDir + viewDir);
		float nh = max (0, dot (s.Normal, h));
		float spec = pow (nh, 100.0 * _SpecPower * s.Gloss);
		spec = smoothstep(_Edge, 1 - _Edge, spec) * s.Specular;

		half3 ramp = tex2D(_Ramp, float2(diff, 0.5)).rgb;
		half4 c;
		c.rgb = (s.Albedo * _LightColor0.rgb * ramp + spec * _LightColor0.rgb * _SpecIntensity) * atten;
		c.a = 1;
		return c;
	}

	struct Input
	{
		fixed4 color;
		float2 uv_MainTex;
		// float3 worldRefl;
		// float3 worldNormal;
		float3 viewDir;
		#ifndef CELERY_SIMPLE
			float4 tSpace0;
			float4 tSpace1;
			float4 tSpace2;
		#else
			float3 worldNormal;
		#endif
		// INTERNAL_DATA
	};

	sampler2D 	_MainTex;
	sampler2D	_Normal;
	sampler2D	_MaskTex;
	samplerCUBE _Cube;
	float		_CubeColoring;
	float		_CubeColoring2;
	float		_CubeIntensity;
	float		_CubePower;
	float		_CubeBlur;
	float		_AmbientBoost;
	float4 		_Color;
	float		_VCol;
	float		_Hue;
	float		_Saturation;
	float		_Value;
	float 		_RimIntensity;
	float 		_RimPower;
	float		_RimColoring;

	void surf (Input IN, inout SurfaceOutputCel o)
	{
		// Expensive shader: Unpack tangent normals and transform to world space
		// Cheap shader: Just use vertex normals (already in world space)
		#ifndef CELERY_SIMPLE
			// Unpack tangent space normal
			half3 tnormal = UnpackNormal(tex2D(_Normal, IN.uv_MainTex));

			// Transform from tangent to world space
			half3 worldNormal;
			worldNormal.x = dot(IN.tSpace0, tnormal);
			worldNormal.y = dot(IN.tSpace1, tnormal);
			worldNormal.z = dot(IN.tSpace2, tnormal);

			// Set output world normal
			o.Normal = worldNormal;

			// Calculate world reflection vector
			float3 worldRefl = reflect(-IN.viewDir, o.Normal);
		#else
			o.Normal = IN.worldNormal;
		#endif

		// Sample main texture
		float4 col = tex2D(_MainTex, IN.uv_MainTex);
		col.a *= _Color.a;

		// Expensive shader: Sample masks texture and perform HSV adjustment
		// Cheap shader: Just multiply with the color value
		#ifndef CELERY_SIMPLE
			// Sample masks texture
			float4 masks = tex2D(_MaskTex, IN.uv_MainTex);

			// Hue/saturation/value adjustment
			float3 hsv = rgb2hsv(col.rgb);
			hsv.x += _Hue - 0.5;
			hsv.y *= _Saturation;
			hsv.z *= _Value;
			col.rgb = lerp(col.rgb, hsv2rgb(hsv), masks.a);

			col.rgb = lerp(col.rgb, col.rgb * _Color.rgb, masks.a);
		#else
			col.rgb *= _Color.rgb;
		#endif

		// Vertex colors
		#if defined(UNITY_COLORSPACE_GAMMA)
			col.rgb *= lerp(1, IN.color.rgb, _VCol);
		#else
			col.rgb *= lerp(1, pow(IN.color.rgb, 2.2), _VCol);
		#endif

		// Set albedo
		o.Albedo = col.rgb;

		// Set alpha
		o.Alpha = col.a;

		// Rim lighting
		half rim = 1.0 - saturate(dot(normalize(IN.viewDir), o.Normal));
		half rimToon = pow(rim, _RimPower);
		rimToon = smoothstep(_Edge, 1 - _Edge, rimToon);

		// Sample cubemap, unless in forwardadd or cheap shader
		#ifdef UNITY_PASS_FORWARDBASE
			#ifndef CELERY_SIMPLE
				// Cubemap
				float3 cube = texCUBElod(_Cube, float4(worldRefl, _CubeBlur)).rgb;
				cube *= pow(rim, _CubePower);
			#endif
		#endif

		// Custom ambient term
		float3 ambient = lerp(unity_AmbientGround, unity_AmbientSky, smoothstep(_Edge, 1 - _Edge, o.Normal.y * 0.5 + 0.5));
		float3 flatAmbient = unity_AmbientSky * (1 + _AmbientBoost);

		#ifndef CELERY_SIMPLE
			o.Specular = masks.r;
			o.Gloss = masks.g;
			o.Rim = masks.b;
		#else
			o.Specular = 1;
			o.Gloss = 1;
			o.Rim = 1;
		#endif

		// Base ambient, rim and cubemap
		#ifdef UNITY_PASS_FORWARDBASE
			// Ambient coloring
			o.Emission += col.rgb * flatAmbient * tex2D(_Ramp, float2(0.5, 0.5)).rgb;

			// Rim
			o.Emission += lerp(1, col.rgb, _RimColoring) * rimToon * _RimIntensity * ambient * o.Rim;

			#ifndef CELERY_SIMPLE
				// Cubemap
				o.Emission += cube * _CubeIntensity * lerp(1, ambient, _CubeColoring) * lerp(1, col.rgb, _CubeColoring2) * o.Specular;
			#endif
		#endif
	}

	// Vertex to fragment interpolation data structure
	struct v2f
	{
		UNITY_POSITION(pos);
		fixed4 color			: COLOR;
		float2 pack0 			: TEXCOORD0; // _MainTex
		half3 worldNormal 		: TEXCOORD1;
		float3 worldPos 		: TEXCOORD2;
		#ifndef CELERY_SIMPLE
			float4 tSpace0 		: TEXCOORD3;
			float4 tSpace1 		: TEXCOORD4;
			float4 tSpace2 		: TEXCOORD5;
		#endif
		float3 vec 				: TEXCOORD6; // Compiler throws error unless this is manually added
		UNITY_SHADOW_COORDS(7)
		UNITY_FOG_COORDS(8)
		UNITY_VERTEX_INPUT_INSTANCE_ID
		UNITY_VERTEX_OUTPUT_STEREO
	};

	float4 _MainTex_ST;

	// Vertex shader
	v2f vert (appdata_full v)
	{
		UNITY_SETUP_INSTANCE_ID(v);
		v2f o;
		UNITY_INITIALIZE_OUTPUT(v2f,o);
		UNITY_TRANSFER_INSTANCE_ID(v,o);
		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
		o.pos = UnityObjectToClipPos(v.vertex);
		o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
		float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
		fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);

		#ifndef CELERY_SIMPLE
			// TBN
			fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
			fixed  tangentSign = v.tangent.w * unity_WorldTransformParams.w;
			fixed3 worldBinormal = cross(worldNormal, worldTangent) * tangentSign;
			o.tSpace0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
			o.tSpace1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
			o.tSpace2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
		#endif

		o.worldPos = worldPos;
		o.worldNormal = worldNormal;
		o.color = v.color;

		UNITY_TRANSFER_SHADOW(o, v.texcoord1.xy); // pass shadow coordinates to pixel shader
		UNITY_TRANSFER_FOG(o, o.pos); // pass fog coordinates to pixel shader
		return o;
	}

	float _Cutout;

	fixed4 frag (v2f IN) : SV_Target
	{
		UNITY_SETUP_INSTANCE_ID(IN);
		// prepare and unpack data
		Input surfIN;
		UNITY_INITIALIZE_OUTPUT(Input, surfIN);
		surfIN.color = IN.color;
		surfIN.uv_MainTex.x = 1.0;
		surfIN.viewDir.x = 1.0;
		surfIN.uv_MainTex = IN.pack0.xy;
		float3 worldPos = IN.worldPos;

		#ifndef USING_DIRECTIONAL_LIGHT
			fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
		#else
			fixed3 lightDir = _WorldSpaceLightPos0.xyz;
		#endif

		fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
		fixed3 viewDir = worldViewDir;
		surfIN.viewDir = viewDir;

		#ifdef UNITY_COMPILER_HLSL
			SurfaceOutputCel o = (SurfaceOutputCel)0;
		#else
			SurfaceOutputCel o;
		#endif

		o.Albedo = 0.0;
		o.Emission = 0.0;
		o.Specular = 0.0;
		o.Alpha = 0.0;
		o.Gloss = 0.0;
		fixed3 normalWorldVertex = fixed3(0,0,1);
		o.Normal = IN.worldNormal;
		normalWorldVertex = IN.worldNormal;

		#ifndef CELERY_SIMPLE
			surfIN.tSpace0 = IN.tSpace0;
			surfIN.tSpace1 = IN.tSpace1;
			surfIN.tSpace2 = IN.tSpace2;
		#else
			surfIN.worldNormal = IN.worldNormal;
		#endif

		// call surface function
		surf (surfIN, o);

		// alpha test
		#if ALPHA_TEST
			clip (o.Alpha - _Cutout);
		#endif

		// compute lighting & shadowing factor
		UNITY_LIGHT_ATTENUATION(atten, IN, worldPos)
		fixed4 c = 0;

		// realtime lighting: call lighting function
		c += LightingCel (o, lightDir, worldViewDir, atten);

		#ifdef UNITY_PASS_FORWARDBASE
			c.rgb += o.Emission;
		#endif

		c.a = o.Alpha;

		// Apply fog
		UNITY_APPLY_FOG(IN.fogCoord, c);

		return c;
	}

	fixed4 _OutlineColor;
	float _OutlineSize;

	// Outline vertex shader
	v2f vert_outline (appdata_full v)
	{
		v2f o;
		UNITY_INITIALIZE_OUTPUT(v2f, o);
		UNITY_TRANSFER_INSTANCE_ID(v, o);
		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

		float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
		float dist = length(_WorldSpaceCameraPos - worldPos);
		v.vertex.xyz += v.normal * min(_OutlineSize * dist, 0.01);

		o.pos = UnityObjectToClipPos(v.vertex);

		o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);

		o.worldPos = worldPos;

		UNITY_TRANSFER_FOG(o,o.pos); // pass fog coordinates to pixel shader
		return o;
	}

	// Outline fragment shader
	fixed4 frag_outline (v2f IN) : SV_Target
	{
		// prepare and unpack data
		Input surfIN;
		UNITY_INITIALIZE_OUTPUT(Input,surfIN);
		surfIN.uv_MainTex.x = 1.0;
		surfIN.viewDir.x = 1.0;
		surfIN.uv_MainTex = IN.pack0.xy;

		#if ALPHA_TEST
			float alpha = tex2D(_MainTex, surfIN.uv_MainTex).a * _Color.a;
			clip (alpha - _Cutout);
		#endif

		fixed4 c = _OutlineColor;

		#ifdef UNITY_PASS_OUTLINE_ONLY
			_OutlineColor.a *= tex2D(_MainTex, surfIN.uv_MainTex).a;
		#endif

		// Apply fog
		UNITY_APPLY_FOG(IN.fogCoord, c);

		return c;
	}

	// Shadow caster fragment shader
	fixed4 frag_shadow (v2f IN) : SV_Target
	{
		UNITY_SETUP_INSTANCE_ID(IN);
		// prepare and unpack data
		Input surfIN;
		UNITY_INITIALIZE_OUTPUT(Input, surfIN);
		surfIN.uv_MainTex.x = 1.0;
		surfIN.viewDir.x = 1.0;
		surfIN.uv_MainTex = IN.pack0.xy;
		#ifdef UNITY_COMPILER_HLSL
			SurfaceOutputCel o = (SurfaceOutputCel)0;
		#else
			SurfaceOutputCel o;
		#endif
		o.Albedo = 0.0;
		o.Emission = 0.0;
		o.Specular = 0.0;
		o.Alpha = 0.0;
		o.Gloss = 0.0;
		fixed3 normalWorldVertex = fixed3(0,0,1);

		// call surface function
		// surf (surfIN, o);

		// #if ALPHA_TEST
			float alpha = tex2D(_MainTex, surfIN.uv_MainTex).a * _Color.a;
			clip (alpha - _Cutout);
		// #endif

		// alpha test
		// clip (o.Alpha - _Cutout);
		SHADOW_CASTER_FRAGMENT(IN)
	}

#endif // CELERY_INCLUDED