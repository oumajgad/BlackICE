float4x4 WorldViewProjectionMatrix;
float2		CameraPosition;

struct VS_INPUT
{
    float2 vPosition  : POSITION;
    float2 vUV		  : TEXCOORD0;
};

struct VS_OUTPUT
{
    float4  vPosition : POSITION;
    float2  vUV		  : TEXCOORD0;
};

texture ArrowTexture;
sampler2D ArrowSampler =
sampler_state
{
    texture = <ArrowTexture>;
    AddressU  = WRAP;
    AddressV  = WRAP;
    MIPFILTER = LINEAR;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};


VS_OUTPUT VertexShader_Front(const VS_INPUT v )
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	float4 Position = float4( v.vPosition.x - CameraPosition.x, 1.0f, v.vPosition.y - CameraPosition.y, 1.0f );
	Position.w = 1;
   	Out.vPosition  = mul( Position, WorldViewProjectionMatrix );
	Out.vUV = v.vUV;

	return Out;
}

float4 PixelShader_Front( VS_OUTPUT v ) : COLOR
{
	float2 Tex = float2(0, 0);

	float4 OutColor = float4( 1, 0, 0, 1 );
	OutColor.rg = frac( v.vUV * 0.2 );
	float a = 1.0f - v.vUV.y;
	OutColor.a = a ;
	OutColor.g = 1.0f - a;
	float2 UV = v.vUV.yx;
	UV.y*=0.15;
	OutColor = tex2D( ArrowSampler, UV );
	return OutColor;
}


technique Front
{
	pass p0
	{
		ALPHABLENDENABLE = True;
		ALPHATESTENABLE = False;

		VertexShader = compile vs_1_1 VertexShader_Front();
		PixelShader = compile ps_2_0 PixelShader_Front();
	}
}