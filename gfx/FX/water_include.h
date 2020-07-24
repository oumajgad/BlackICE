#ifndef WATER_INCLUDE_H
#define WATER_INCLUDE_H
texture NormalTex < string name = "sea_normal.dds"; >;
texture ColorTex < string name = "water.dds"; >;
texture OverlayTex < string name = "water.dds"; >;
texture FOWTex < string name = "Base.tga"; >;
texture color0 < string name = "Base.tga"; >;	// province color 0 
texture color1 < string name = "Base.tga"; >;	// province color 1
texture stripes < string name = "Base.tga"; >;	// color0 color1 mix


sampler WorldColor  =
sampler_state
{
    Texture = <ColorTex>;
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

///

sampler WaterNormalMap  =
sampler_state
{
    Texture = <NormalTex>;
    MinFilter = Linear; //Point;
    MagFilter = Linear;
    MipFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
//    AddressW = Wrap;
};

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

sampler ColorTexture0  =
sampler_state
{
    Texture = <color0>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = None;
    AddressU = Wrap;
    AddressV = Wrap;
};
sampler ColorTexture1  =
sampler_state
{
    Texture = <color1>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = None;
    AddressU = Wrap;
    AddressV = Wrap;
};
sampler StripesTexture  =
sampler_state
{
	Texture = <stripes>;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = None;
	AddressU = Wrap;
	AddressV = Wrap;
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////


float Fresnel(float NdotL, float fresnelBias, float fresnelPow)

{
  float facing = (1.0 - NdotL);
  return max(fresnelBias +
             (1.0 - fresnelBias) * pow(facing, fresnelPow), 0.0);
}

const float WRAP = 0.8;
const float WaveModOne = 3.0;
const float WaveModTwo =  8.0;

const float SpecValueOne = 20.0;
const float SpecValueTwo =  5.0;

const float vWaterTransparens = 1.0f;//0.6; //more transparance lets you see more of background
const float vColorMapFactor = 2.5f; //how much colormap

#endif

#ifdef SIMPLE

#ifdef PROVINCE_COLOR
float4 PixelShader_WaterSimpleColor( VS_OUTPUT_WATER IN ) : COLOR
#else
float4 PixelShader_WaterSimple( VS_OUTPUT_WATER IN ) : COLOR
#endif
{
	float4 OutColor = float4( 0.3, 0.4, 0.5, 1 );
	

#ifdef PROVINCE_COLOR
	float4 ProvinceColor  = tex2D( ColorTexture0, IN.WorldTexture );
	OutColor = lerp( OutColor, ProvinceColor, 1.0f );
#endif

	float FOW  = saturate( tex2D( FOWTexture, IN.WorldTexture  ).b + 1.0 );
	OutColor.rgb *= FOW;
	return OutColor;
}

#else // SIMPLE

#ifdef FAR
#ifdef PROVINCE_COLOR
float4 PixelShader_WaterFarColor( VS_OUTPUT_WATER IN ) : COLOR
#else // PROVINCE_COLOR
float4 PixelShader_WaterFar( VS_OUTPUT_WATER IN ) : COLOR
#endif // PROVINCE_COLOR
#else // FAR
#ifdef PROVINCE_COLOR
float4 PixelShader_WaterColor( VS_OUTPUT_WATER IN ) : COLOR
#else // PROVINCE_COLOR
float4 PixelShader_Water( VS_OUTPUT_WATER IN ) : COLOR
#endif // PROVINCE_COLOR
#endif // FAR
{
	float3 WorldColorColor = tex2D( WorldColor, IN.vUV ).rgb;

#ifndef FAR

	/* Removed waves - Dozed

	float2 UV = IN.WorldTexture * 256;
	float2 coordA = UV * 3;
	coordA.xy += 0.1;
	float2 coordB = UV;
	coordB.y += 0.1;
	float2 coordC = UV * 2;
	coordC.y += 0.15;
	float2 coordD = UV * 5;
	coordD.y += 0.3;	
		
	float3 vBumpA = tex2D( WaterNormalMap, coordA.xy ).rgb;
	coordB.x -= 0.03 * Time;
	coordB.y += 0.05 * Time;	
	float3 vBumpB = tex2D( WaterNormalMap, coordB.xy ).rgb;
	coordC.x += 0.02 * Time;
	coordC.y -= 0.07 * Time;
	float3 vBumpC = tex2D( WaterNormalMap, coordC.xy ).rgb;
	coordD.x += 0.06 * Time;
	coordD.y -= 0.02 * Time;
	float3 vBumpD = tex2D( WaterNormalMap, coordD.xy + 0.01 * Time ).rgb;

	float3 vBumpTex = normalize(WaveModOne * (vBumpA.xyz + vBumpB.xyz +
                                 vBumpC.xyz + vBumpD.xyz) - WaveModTwo);

	                                         	
	float3 eyeDir = normalize( float3( 0.0, 1.0, 1.0 ) ); 
	float NdotL = max(dot(eyeDir, (vBumpTex/2)), 0);
	
	NdotL = saturate((NdotL + WRAP) / (1 + WRAP));
	
	float3 color = NdotL * WorldColorColor; // * vColorMapFactor);
	
	//return float4( color, 1 );
	float3	reflVector = -reflect( float3( 0.0, 0.5, 1.0 ), vBumpTex );
	float	specular = dot( normalize( reflVector), eyeDir );	 
	specular = saturate( specular );
	
	specular = pow( specular, SpecValueOne );
	color += (specular/SpecValueTwo);

	*/

	//Smooth lighter coastline with better ocean color - Dozed

	//Grayscale of expected color
	float gray = (WorldColorColor.r + WorldColorColor.g + WorldColorColor.b) / 3;
	gray = pow(gray, 1.2);

	//New Color
	float3 light = float3(66/255.0, 79/255.0, 94/255.0);

	//Combine
	float3 color = light * gray;

#else

	//float3 color = WorldColorColor* 0.8;

	//Smooth lighter coastline with better ocean color - Dozed

	//Grayscale of expected color
	float gray = (WorldColorColor.r + WorldColorColor.g + WorldColorColor.b) / 3;
	gray = pow(gray, 1.2);

	//New Color
	float3 light = float3(66/255.0, 79/255.0, 94/255.0);

	//Combine
	float3 color = light * gray;

#endif
	
	float2 WorldTexUV = IN.WorldTexture;
	WorldTexUV += 0.5 / float2( FOW_SIZE_X, FOW_SIZE_Y );

	float xoffset = 0.5 / FOW_SIZE_X;
	float yoffset = 0.5 / FOW_SIZE_Y;

#ifdef PROVINCE_COLOR
	float4 ProvinceColor  = tex2D( ColorTexture0, WorldTexUV + float2( -xoffset, yoffset) );
	ProvinceColor  += tex2D( ColorTexture0, WorldTexUV + float2( xoffset, yoffset) );
	ProvinceColor  += tex2D( ColorTexture0, WorldTexUV + float2( -xoffset, -yoffset) );
	ProvinceColor  += tex2D( ColorTexture0, WorldTexUV + float2( xoffset, -yoffset) );
	ProvinceColor /= 4;

	float4 ProvinceColor1  = tex2D( ColorTexture1, WorldTexUV + float2( -xoffset, yoffset) );
	ProvinceColor1  += tex2D( ColorTexture1, WorldTexUV + float2( xoffset, yoffset) );
	ProvinceColor1  += tex2D( ColorTexture1, WorldTexUV + float2( -xoffset, -yoffset) );
	ProvinceColor1  += tex2D( ColorTexture1, WorldTexUV + float2( xoffset, -yoffset) );
	ProvinceColor1 /= 4;

	float2 TerrainCoord = IN.WorldPos;
	TerrainCoord += 0.5;
	TerrainCoord /= 8.0;
	float vColor = tex2D( StripesTexture, TerrainCoord ).a;
	ProvinceColor = lerp( ProvinceColor, ProvinceColor1, vColor );
	color = lerp( color, ProvinceColor, 0.8f );
	float4 OutColor = float4( color, vWaterTransparens );
	float FOW = 1;
#else
	
	float FOW  = tex2D( FOWTexture, WorldTexUV + float2( -xoffset, yoffset) ).b;
	FOW  += tex2D( FOWTexture, WorldTexUV + float2( xoffset, yoffset) ).b;
	FOW  += tex2D( FOWTexture, WorldTexUV + float2( -xoffset, -yoffset) ).b;
	FOW  += tex2D( FOWTexture, WorldTexUV + float2( xoffset, -yoffset) ).b;
	FOW /= 4;

	//return float4(FOW.rrr, 1.0);
	//FOW = saturate ( FOW * 2 - 1 );
	//FOW = saturate ( FOW + 0.5 );
	
	//Removed FOW - Dozed
	float4 OutColor = float4( color /* * FOW */, vWaterTransparens);
	//OutColor.rgb = float3(0,0,0);

#endif // PROVINCE_COLOR

#ifdef FAR
	float4 overlay = tex2D( Overlay, IN.WorldPos / 512.0f );
	float3 overlay_mask = overlay < .5;
	
	OutColor.rgb = overlay_mask * (2 * overlay.rgb * OutColor.rgb) + ( 1.0f - overlay_mask )*(1 - 2 * (1 - overlay.rgb) * (1 - OutColor.rgb));
	OutColor.rgb *= step(0.01f, FOW );
	//OutColor.a = OutColor.a * overlay.a;
#endif
	return OutColor;
}

#endif // SIMPLE

#undef SIMPLE
#undef PROVINCE_COLOR
#undef FAR