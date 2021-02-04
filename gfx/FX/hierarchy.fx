float4x4 WorldViewProjectionMatrix;
float2		CameraPosition;
float		Time;

struct VS_INPUT
{
    float2 vPosition  : POSITION;
    float3 vUV_Range  : TEXCOORD0;
	float4 Color	: COLOR;
};

struct VS_OUTPUT
{
    float4  vPosition : POSITION;
    float3  vUV_Range : TEXCOORD0;
	float4	Color : COLOR;
};

texture LineTexture;
sampler2D LineSampler =
sampler_state
{
    texture = <LineTexture>;
    AddressU  = WRAP;
    AddressV  = WRAP;
    MIPFILTER = NONE;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};


VS_OUTPUT VertexShader_Hierarchy(const VS_INPUT v )
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	float4 Position = float4( v.vPosition.x - CameraPosition.x, 2.0f, v.vPosition.y - CameraPosition.y, 1.0f );
	Position.w = 1;
   	Out.vPosition  = mul( Position, WorldViewProjectionMatrix );
	Out.vUV_Range = v.vUV_Range.xyz;
	Out.vUV_Range.x *= 0.5f;
	Out.vUV_Range.x += 0.5f - 0.5f * v.vUV_Range.z;
	Out.vUV_Range.y += Time * 0.03 * v.vUV_Range.z;
	Out.Color = v.Color;
	return Out;
}

float4 PixelShader_Hierarchy( VS_OUTPUT v ) : COLOR
{
	float4 OutColor = tex2D( LineSampler, v.vUV_Range.xy ) * v.Color;
	return OutColor;
}


technique Hierarchy
{
	pass p0
	{
		ALPHABLENDENABLE = True;
		ALPHATESTENABLE = False;
		ZWRITEENABLE = False;
		VertexShader = compile vs_1_1 VertexShader_Hierarchy();
		PixelShader = compile ps_2_0 PixelShader_Hierarchy();
	}
}