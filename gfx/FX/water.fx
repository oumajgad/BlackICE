

#define FOW_SIZE_X 1024
#define FOW_SIZE_Y 512
const float WATER_RATION = 0.5;
const float MAIN_TILING_FACTOR = 0.25;
const float FADE_DISTANCE = 100;


#define X_OFFSET 0.5
#define Z_OFFSET 0.5

float	ColorMapHeight;
float	ColorMapWidth;

float	ColorMapTextureHeight;
float	ColorMapTextureWidth;

float	MapWidth;
float	MapHeight;

float	BorderWidth;
float	BorderHeight;


float4x4 WorldViewProjectionMatrix; 
float4x4 WorldMatrix;
float4x4 ViewProjectionMatrix;
float3	LightPosition;
float3	CameraPosition;
float	Time;
float	vAlpha;
float4	MinMaxUV;

const float3 offY = float3(0.11, 0.74, 0.43);
const float3 offZ = float3(0.47, 0.19, 0.78);


struct VS_INPUT_WATER
{
    float4 position_uv			: POSITION;
};

struct VS_OUTPUT_WATER
{
    float4 position				: POSITION;
    float2 vUV					: TEXCOORD0;
	float2 WorldTexture			: TEXCOORD1;
	float2 WorldPos				: TEXCOORD5;
 };

VS_OUTPUT_WATER VertexShader_Water(const VS_INPUT_WATER IN )
{
	VS_OUTPUT_WATER OUT;
	float2 pos = IN.position_uv.xy;
	pos -= CameraPosition.xz;
	OUT.position = mul( float4(pos.x, -0.32, pos.y, 1.0), ViewProjectionMatrix );
	OUT.vUV = MinMaxUV.xy + IN.position_uv.zw * (MinMaxUV.zw - MinMaxUV.xy);
	OUT.WorldTexture.xy = IN.position_uv.zw;
	OUT.WorldPos = IN.position_uv.xy;
	return OUT;
}

VS_OUTPUT_WATER VertexShader_WaterSimple(const VS_INPUT_WATER IN )
{
    VS_OUTPUT_WATER OUT;
   	float2 pos = IN.position_uv.xy;
	pos -= CameraPosition.xz;
	OUT.position = mul( float4(pos.x, -0.32, pos.y, 1.0), ViewProjectionMatrix );
	OUT.vUV = MinMaxUV.xy + IN.position_uv.zw * (MinMaxUV.zw - MinMaxUV.xy);
	OUT.WorldTexture.xy = IN.position_uv.zw;
	OUT.WorldPos = IN.position_uv.xy;
    return OUT;
}


// In order to minimize copy and paste code, the water pixel shaders can be included with different flags
#include "water_include.h"
#define PROVINCE_COLOR
#include "water_include.h"
#define SIMPLE
#include "water_include.h"
#define PROVINCE_COLOR
#define SIMPLE
#include "water_include.h"
#define FAR
#include "water_include.h"
#define PROVINCE_COLOR
#define FAR
#include "water_include.h"


////////////////
technique WaterFar
{
	pass p0
	{
		ALPHATESTENABLE = False;
		ALPHABLENDENABLE = False;

		VertexShader = compile vs_2_0 VertexShader_Water();
		PixelShader = compile ps_2_0 PixelShader_WaterFar();
	}
}

technique WaterFarColor
{
	pass p0
	{
		ALPHATESTENABLE = False;
		ALPHABLENDENABLE = False;

		VertexShader = compile vs_2_0 VertexShader_Water();
		PixelShader = compile ps_2_0 PixelShader_WaterFarColor();
	}
}

technique WaterSimple
{
	pass p0
	{
		ALPHABLENDENABLE = True;

		VertexShader = compile vs_1_1 VertexShader_WaterSimple();
		PixelShader = compile ps_2_0 PixelShader_WaterSimple();
	}
}
technique WaterSimpleColor
{
	pass p0
	{
		ALPHABLENDENABLE = True;

		VertexShader = compile vs_1_1 VertexShader_WaterSimple();
		PixelShader = compile ps_2_0 PixelShader_WaterSimpleColor();
	}
}

technique WaterNear
{
	pass p0
	{
		ALPHATESTENABLE = True;
		ALPHABLENDENABLE = True;

		VertexShader = compile vs_2_0 VertexShader_Water();
		PixelShader = compile ps_2_0 PixelShader_Water();
	}
}

technique WaterNearColor
{
	pass p0
	{
		ALPHATESTENABLE = True;
		ALPHABLENDENABLE = True;

		VertexShader = compile vs_2_0 VertexShader_Water();
		PixelShader = compile ps_2_0 PixelShader_WaterColor();
	}
}
