
float4x4 WorldMatrix;
float4x4 ViewProjectionMatrix;

float SizeOffset = 0.0;
float SizeFrame = 5;
float4 CountryColor = float4(0.8, 0, 0, 1);
float4 SelectionColor = float4(0, 1, 0, 0);
float SelectionIntensity;
float Selected;
float CounterScale;
float4 vOtherColor;

texture BackgroundTex;
sampler2D BackgroundSampler =
sampler_state
{
    texture = <BackgroundTex>;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
    AddressW  = CLAMP;
    MIPFILTER = LINEAR;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

texture MaskTex;
sampler2D MaskSampler =
sampler_state
{
    texture = <MaskTex>;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
    AddressW  = CLAMP;
    MIPFILTER = LINEAR;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

texture SizeTex;
sampler2D SizeSampler =
sampler_state
{
    texture = <SizeTex>;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
    AddressW  = CLAMP;
    MIPFILTER = LINEAR;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

texture CounterTex;
sampler2D CounterSampler =
sampler_state
{
    texture = <CounterTex>;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
    AddressW  = CLAMP;
    MIPFILTER = LINEAR;
    //MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
	MinFilter = Anisotropic;

    MaxAnisotropy = 4;
};

struct VS_INPUT
{
   float3 Position : POSITION;
   float2 TexCoord : TEXCOORD0;
};

struct VS_OUTPUT
{
   float4 Position :        POSITION;
   float2 TexCoord :        TEXCOORD0;
};

VS_OUTPUT Counter_VS( VS_INPUT In )
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	float4x4 WorldViewProjectionMatrix = mul(WorldMatrix, ViewProjectionMatrix);
	Out.Position = mul( float4(In.Position.xyz * CounterScale, 1), WorldViewProjectionMatrix );
	Out.TexCoord = In.TexCoord;

	return Out;
}



float4 Counter_PS( VS_OUTPUT In ) : COLOR
{
	float4 CounterColor = tex2D( CounterSampler, In.TexCoord);//CounterTex );
			
	
	float4 BgColor = tex2D( BackgroundSampler, In.TexCoord );
	float4 SizeColor = tex2D( SizeSampler,
	                          float2( (In.TexCoord.x + SizeFrame) * SizeOffset,
							         In.TexCoord.y ));
	float4 MaskColor = tex2D( MaskSampler, In.TexCoord );
	float vMask = MaskColor.r;
	float SelectionAlpha = MaskColor.b * Selected;

	float vUseOtherColorBlack = saturate( ( ( In.TexCoord.x + In.TexCoord.y ) - 1.57f ) * 1000.0f ) * vOtherColor.a;
	float vUseOtherColor = saturate( ( ( In.TexCoord.x + In.TexCoord.y ) - 1.6f ) * 1000.0f ) * vOtherColor.a;
	vUseOtherColorBlack -= vUseOtherColor;
	float3 vModifiedCountryColor = lerp( CountryColor.rgb, vOtherColor.rgb, vUseOtherColor * vMask );
	vModifiedCountryColor = lerp( vModifiedCountryColor.rgb, float3( 0.0f, 0.0f, 0.0f ), vUseOtherColorBlack * vMask );

	float4 FinalColor = float4(vMask * vModifiedCountryColor, vMask);
	FinalColor = float4(FinalColor.rgb * BgColor.rgb, BgColor.a);

	FinalColor.rgb = lerp(FinalColor.rgb, CounterColor.rgb, CounterColor.a);
	FinalColor.rgb = lerp(FinalColor.rgb, SizeColor.rgb, SizeColor.a);
	FinalColor.rgb = FinalColor.rgb * (1- SelectionAlpha) +
	                 ( MaskColor.g * SelectionColor.rgb * SelectionAlpha * SelectionIntensity );
	FinalColor.a += SelectionAlpha * Selected;

	return FinalColor;
}

technique Standard
{
	pass p0
	{
		ZENABLE = True;
		ZWRITEENABLE = True;
		ALPHATESTENABLE = True;
		ALPHABLENDENABLE = True;
	
		VertexShader = compile vs_2_0 Counter_VS();
		PixelShader = compile ps_2_0 Counter_PS();
	}
}