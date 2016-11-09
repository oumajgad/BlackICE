texture SectorTex;

float4x4 WorldMatrix; 
float4x4 ViewMatrix;
float4x4 ProjectionMatrix;

float2 vStrength = float2(0.0f, 0.0f);


sampler2D SecantTexture = 
sampler_state 
{
    texture = <SectorTex>;
    AddressU  = CLAMP;        
    AddressV  = CLAMP;
    AddressW  = CLAMP;
    MIPFILTER = LINEAR;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
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
   float2 vStrength :		TEXCOORD1; // we all float down here
};

VS_OUTPUT Circle_VS( VS_INPUT In )
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	float4x4 WorldView = mul(WorldMatrix, ViewMatrix);
	float4 Position = float4( In.Position, 1.0f );
	float3 P = mul( Position, (float4x3)WorldView);
	Out.Position  = mul(float4(P, 1), ProjectionMatrix);
	
	Out.TexCoord = In.TexCoord;
	Out.vStrength = vStrength;
	return Out;
}


float4 Circle_PS( VS_OUTPUT In ) : COLOR
{
	float DiffuseColor = tex2D( SecantTexture, In.TexCoord ).r;
	//0     0.5   1.0
	//c1 -> c2 -> c3	
	float3 StrengthColor = lerp( float3(1.0f,0.0f,0.0f), float3(1.0f,1.0f,0.0f), saturate(In.vStrength.x * 2.0f) );
	StrengthColor = lerp( StrengthColor, float3(0.0f,1.0f,0.0f), saturate((In.vStrength.x - 0.5f)*2.0f) );
	
	//return float4(In.vStrength.yyy,1.0f - In.vStrength.y);
	return float4(DiffuseColor * StrengthColor, DiffuseColor * 0.3f * In.vStrength.y);
}


technique Standard
{
	pass p0
	{
		ZENABLE = False;
		ZWRITEENABLE = False;
		ALPHABLENDENABLE = True;
		ALPHATESTENABLE = False;
	
		VertexShader = compile vs_2_0 Circle_VS();
		PixelShader = compile ps_2_0 Circle_PS();
	}
}

