Shader "Celery/CeleryStandard"
{
	Properties
	{
		// Textures
		_MainTex ("Texture", 2D) = "white" {}
		_Color ("Color", Color) = (1, 1, 1, 1)
		_VCol ("Vertex Colors", Range(0, 1)) = 1
		_Hue ("Hue", Range(0, 1)) = .5
		_Saturation ("Saturation", Range(0, 2)) = 1
		_Value ("Value", Range(0, 2)) = 1
		_Edge ("Cel Shading", Range(0, 0.5)) = 0.475
		[NoScaleOffset] _Normal ("Normal Map", 2D) = "bump" {}
		[NoScaleOffset] _MaskTex ("Specular (R), Gloss (G), Rim (B), Color Mask (A)", 2D) = "white" {}
		[NoScaleOffset] _Ramp ("Ramp", 2D) = "white" {}

		// Cubemap
		[NoScaleOffset] _Cube ("Cubemap", CUBE) = "" {}
		_CubeIntensity ("Cube Intensity", Range(0, 2)) = 1
		_CubePower ("Cube Power", Range(0.001, 2)) = 1
		_CubeColoring ("Cube Ambient Coloring", Range(0, 1)) = 0
		_CubeColoring2 ("Cube Albedo Coloring", Range(0, 1)) = 0
		_CubeBlur ("Cube Blur", Range(0, 7)) = 0

		// Rim lighting
		_RimIntensity ("Rim Intensity", Range(0, 1)) = 1
		_RimPower ("Rim Power", Range(0.5, 4.0)) = 1.25
		_RimColoring ("Rim Coloring", Range(0, 1.0)) = 0.75

		// Specular
		_SpecIntensity ("Specular Intensity", Range(0, 1)) = 0.5
		_SpecPower ("Specular Power", Range(0, 1)) = 0.1

		// Lighting
		_AmbientBoost ("Ambient Boost", Range(0, 2)) = 0.5

		// Outline
		// _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
		// _OutlineSize ("Outline Size", Range(0, 0.02)) = 0.01

		[Toggle(ALPHA_TEST)] _AlphaTest ("Alpha Test", Float) = 0
		_Cutout ("Alpha Threshold", Range(0, 1)) = 0.5
		_Cull ( "Culling", Int ) = 2
	}
	SubShader
	{
		Tags { "RenderType" = "Opaque" "Queue"="Geometry" }

		Cull [_Cull]

		CGINCLUDE

			#pragma multi_compile __ ALPHA_TEST

		ENDCG

		// ---- Forward rendering base pass:
		Pass
		{
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }
			ColorMask RGB

			CGPROGRAM
				// compile directives
				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_fog
				#pragma multi_compile_fwdbase //novertexlight noshadowmask nodynlightmap nodirlightmap nolightmap

				#define UNITY_PASS_FORWARDBASE

				#include "CeleryCore.cginc"

			ENDCG
		}

		// ---- Outline pass:
		// Pass
		// {
		// 	Name "FORWARD"
		// 	Tags { "LightMode" = "ForwardBase" }
		// 	ColorMask RGB

		// 	Blend SrcAlpha OneMinusSrcAlpha
		// 	Cull Front

		// 	CGPROGRAM
		// 		// compile directives
		// 		#pragma vertex vert_outline
		// 		#pragma fragment frag_outline
		// 		#pragma multi_compile_fog
		// 		#pragma multi_compile_fwdbase //novertexlight noshadowmask nodynlightmap nodirlightmap nolightmap

		// 		#define UNITY_PASS_OUTLINE

		// 	ENDCG
		// }

		// ---- Forward rendering additive lights pass:
		Pass {
			Name "FORWARD"
			Tags { "LightMode" = "ForwardAdd" }
			ZWrite Off Blend One One
			ColorMask RGB

			CGPROGRAM
				// compile directives
				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_fog
				#pragma skip_variants INSTANCING_ON
				#pragma multi_compile_fwdadd_fullshadows //novertexlight noshadowmask nodynlightmap nodirlightmap nolightmap

				#define UNITY_PASS_FORWARDADD

				#include "CeleryCore.cginc"

			ENDCG
		}

		// ---- Shadow caster pass:
		Pass
		{
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }
			ZWrite On ZTest LEqual

			CGPROGRAM
				// compile directives
				#pragma vertex vert
				#pragma fragment frag_shadow
				#pragma skip_variants FOG_LINEAR FOG_EXP FOG_EXP2
				#pragma multi_compile_shadowcaster novertexlight noshadowmask nodynlightmap nodirlightmap nolightmap

				#define UNITY_PASS_SHADOWCASTER

				#include "CeleryCore.cginc"

			ENDCG
		}
	}
	Fallback "Diffuse"
}