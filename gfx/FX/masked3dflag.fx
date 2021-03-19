float4x4	WorldViewProjectionMatrix;
float3		CameraPosition;
float4		FlagOffset;
float2		FrameOffset;

struct VS_INPUT
{
    float2 vPosition	: POSITION;
	float2 vUV			: TEXCOORD0;
};

struct VS_OUTPUT
{
    float4  vPosition	: POSITION;
    float4  vMaskFlag	: TEXCOORD0;
	float2	vFrame		: TEXCOORD1;
};

texture FlagTexture;
sampler2D FlagSampler =
sampler_state
{
    texture = <FlagTexture>;
    AddressU  = WRAP;
    AddressV  = WRAP;
    MIPFILTER = LINEAR;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

texture MaskTexture;
sampler2D MaskSampler =
sampler_state
{
    texture = <MaskTexture>;
    AddressU  = WRAP;
    AddressV  = WRAP;
    MIPFILTER = LINEAR;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

texture FrameTexture;
sampler2D FrameSampler =
sampler_state
{
    texture = <FrameTexture>;
    AddressU  = WRAP;
    AddressV  = WRAP;
    MIPFILTER = LINEAR;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

VS_OUTPUT VertexShader_Masked3dFlag(const VS_INPUT v )
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	float4 Position = float4( v.vPosition.x + CameraPosition.x, 1.0f + CameraPosition.y , v.vPosition.y + CameraPosition.z, 1.0f );
	Position.w = 1;
   	Out.vPosition  = mul( Position, WorldViewProjectionMatrix );
	Out.vMaskFlag.xy = v.vUV;
	Out.vMaskFlag.zw = v.vUV;

	// Totaly ad-hoc and magic numbers but it's working for allied objectives in semper fi.
	Out.vMaskFlag.z *= 0.9;
	Out.vMaskFlag.z += 0.05;
	Out.vMaskFlag.w *= 1.3;
	Out.vMaskFlag.w -= 0.1;

	Out.vMaskFlag.z /= FlagOffset.x;
	Out.vMaskFlag.z += FlagOffset.z;
	Out.vMaskFlag.w /= FlagOffset.y;
	Out.vMaskFlag.w += FlagOffset.w;
	Out.vFrame = v.vUV;
	Out.vFrame.x *= FrameOffset.x;
	Out.vFrame.x += FrameOffset.y;

	return Out;
}

float4 PixelShader_Masked3dFlag( VS_OUTPUT v ) : COLOR
{
	float4 OutColor = tex2D( FrameSampler, v.vFrame );
	float2 MaskUV = v.vMaskFlag;

    float4 MaskColor = tex2D( MaskSampler, MaskUV );
	float4 FlagColor = tex2D( FlagSampler, v.vMaskFlag.zw );
	FlagColor.a = MaskColor.g;

	FlagColor.a = saturate( FlagColor.a - OutColor.a );
	FlagColor.rgb *= FlagColor.a;
	OutColor.rgb *= OutColor.a;
	OutColor += FlagColor;
	return OutColor;
}


technique Masked3dFlag
{
	pass p0
	{
		ALPHABLENDENABLE = True;
		ALPHATESTENABLE = False;

		VertexShader = compile vs_1_1 VertexShader_Masked3dFlag();
		PixelShader = compile ps_2_0 PixelShader_Masked3dFlag();
	}
}