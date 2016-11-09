

#define FOW_SIZE_X 1024
#define FOW_SIZE_Y 1024

#define X_OFFSET 0.5
#define Y_OFFSET 0.5


float4x4 WorldViewProjectionMatrix; 
float4x4 WorldMatrix;
float4x4 ViewProjectionMatrix;
float3	CameraPosition;
float	Time;

struct VS_INPUT_TI
{
    float4 position_uv			: POSITION;
};

struct VS_OUTPUT_TI
{
    float4 position				: POSITION;
	float2 WorldTexture			: TEXCOORD1;
 };

texture FOWTex < string name = "Base.tga"; >;
texture OverlayTex < string name = "Base.tga"; >;
texture CloudTex < string name = "Base.tga"; >;

sampler FOWTexture  =
sampler_state
{
    Texture = <FOWTex>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = None;
    AddressU = Wrap;
    AddressV = Wrap;
};

sampler Overlay  =
sampler_state
{
    Texture = <OverlayTex>;
    MinFilter = Linear; //Point;
    MagFilter = Point;
    MipFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
};


sampler Cloud  =
sampler_state
{
    Texture = <CloudTex>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
};

float3 FowColor = float3( 0.0, 0.0, 0.0 );
float3 TiColor = float3( 0.75, 0.70, 0.5 );

VS_OUTPUT_TI VertexShader_TI(const VS_INPUT_TI IN )
{
	VS_OUTPUT_TI OUT;
	float2 pos = IN.position_uv.xy;
	pos -= CameraPosition.xz;
	OUT.position = mul( float4(pos.x, 0.0, pos.y, 1.0), ViewProjectionMatrix );
	OUT.WorldTexture.xy = IN.position_uv.zw;
	return OUT;
}


float4 PixelShader_TIFar( const VS_OUTPUT_TI v ) : COLOR
{
	float2 WorldTexUV = v.WorldTexture;
	float2 tsize = 1.0 / float2( FOW_SIZE_X, FOW_SIZE_Y );
	WorldTexUV -= 0.25 * tsize;
	
	float FOWTI = tex2D( FOWTexture, WorldTexUV ).r;
	FOWTI	   += tex2D( FOWTexture, float2(WorldTexUV.x + tsize.x, WorldTexUV.y ) ).r;
	FOWTI      += tex2D( FOWTexture, float2(WorldTexUV.x, WorldTexUV.y + tsize.y) ).r;
	FOWTI      += tex2D( FOWTexture, WorldTexUV + tsize ).r;
	FOWTI *= 0.25;

	//FOWTI -= 0.2;
	//FOWTI *= 1.2;
	FOWTI = saturate(FOWTI);

	if ( FOWTI < 0.1 )
		FOWTI = 0.0;
	//FOWTI = 1.0;
	//float4 OutColor = float4(FOWTI < 0.5, 0, FOWTI > 0.5, 1.0 - FOWTI);
	float4 OutColor = float4(0, 0, 0, 1.0 - FOWTI);
	return OutColor;
}
////////////////
technique TerraIncognitaFar
{
	pass p0
	{
		ALPHATESTENABLE = True;
		ALPHABLENDENABLE = True;
		ZEnable = False;
		ZWriteEnable = False;
		VertexShader = compile vs_2_0 VertexShader_TI();
		PixelShader = compile ps_2_0 PixelShader_TIFar();
	}
}

technique TerraIncognitaNear
{
	pass p0
	{
		ALPHATESTENABLE = True;
		ALPHABLENDENABLE = True;
		ZEnable = False;
		ZWriteEnable = False;
	
		VertexShader = compile vs_2_0 VertexShader_TI();
		PixelShader = compile ps_2_0 PixelShader_TIFar();
	}
}
