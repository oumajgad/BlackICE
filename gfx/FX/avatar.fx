float4x4 ViewProjectionMatrix;
float4x4 WorldMatrix;
float3 CameraPosition;
float4x4 matBones[45] : Bones;
float3 LightDirection;
float Time;

float4 TerrainColor   = float4(0.2, 0.32, 0.1, 1);

// DESERT COLOR float4 TerrainColor   = float4(0.96, 0.75, 0.24, 1);
// SNOW COLOR float4 TerrainColor   = float4(0.99, 0.99, 1.0, 1);
// WOOD Color float4 TerrainColor   = float4(0.2, 0.32, 0.1, 1);

float TRACK_SPEED = 2.5;

// debug flags
//#define DEBUG_ONLY_SPECULAR
//#define DEBUG_ONLY_DIFFUSE
//#define DEBUG_ONLY_COLORMAP
//#define DEBUG_SHOW_SPECULARMAP
//#define DEBUG_SHOW_TEXCOORDS

// select lighting model to use
//#define LIGHTMODEL_WRAP
//#define LIGHTMODEL_HALFLAMBERT
#define LIGHTMODEL_PHONG

const int SKINNING_INFLUENCES = 2;

float SpecularPower = 25;
float Specularity = 1.0;
const float WRAP = 0.6;

const float INTENSITY = 1.0;

texture tex0 : DiffuseTexture;
sampler2D DiffuseMap =
sampler_state
{
    texture = <tex0>;
    AddressU  = Wrap;
    AddressV  = Wrap;
    AddressW  = Clamp;
    MipFilter = Linear;
    MagFilter = Linear;
	MinFilter = Anisotropic;

    MaxAnisotropy = 4;
};

texture tex1 : SpecularTexture;
sampler2D SpecularMap =
sampler_state
{
    texture = <tex1>;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
    AddressW  = CLAMP;
    MIPFILTER = LINEAR;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

struct VS_INPUT
{
    float4 vPosition   : POSITION;
    float3 vNormal     : NORMAL;
	float4 vTangent    : TANGENT;
	float2 vTexCoord0  : TEXCOORD0;
	float4 boneIndices : BLENDINDICES;
    float4 boneWeights : BLENDWEIGHT;
};

struct VS_OUTPUT
{
    float4 vPosition  : POSITION;
	float2 vTexCoord0 : TEXCOORD0;
	
	float4 LightDirection : TEXCOORD1;
	float Specular : TEXCOORD2;
};

VS_OUTPUT SkinnedAvatarVS(const VS_INPUT v )
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
		
	float4 skinnedPosition = (float4)0;
	float4 skinnedNormal   = (float4)0;
	float4 skinnedTangent  = (float4)0;
	
	float4 vPosition = float4(v.vPosition.xyz, 1.0);
		
	// skinning
	for( int i = 0; i < SKINNING_INFLUENCES; ++i )
    {
    	float4x4 mat = matBones[ v.boneIndices[i] ];

		float4 offset = mul( vPosition, mat ) * v.boneWeights[i];
		skinnedPosition += offset;
		
		offset = mul( normalize(v.vNormal), mat )  * v.boneWeights[i];
		skinnedNormal += offset;

		offset = mul( normalize(v.vTangent), mat ) * v.boneWeights[i];
		skinnedTangent += offset;
	}
	
	float3 vLightDirection = normalize(skinnedPosition - CameraPosition );
	
	skinnedNormal  = normalize(skinnedNormal);
	skinnedTangent = normalize(skinnedTangent);
	float3 binormal = cross(skinnedTangent.xyz, skinnedNormal.xyz ) * v.vTangent.w;
	normalize(binormal);
	
	// transform light direction into tangent space
	float3x3 matTBN = float3x3(skinnedTangent.xyz,
	                           binormal,
							   skinnedNormal.xyz);
	Out.LightDirection.xyz = mul(matTBN, -vLightDirection);
	Out.LightDirection.w = skinnedPosition.y;
	
	Out.vPosition = mul(skinnedPosition, ViewProjectionMatrix );
	Out.vTexCoord0 = v.vTexCoord0;
	
	
	float3 E = mul(matTBN, normalize(skinnedPosition - CameraPosition ));
	float3 H = normalize(E - vLightDirection); 				//half angle vector
	Out.Specular = pow( max(0, dot(skinnedNormal.xyz, H) ), SpecularPower ) * Specularity * INTENSITY;
	
	return Out;
}

float4 SkinnedAvatarPS( VS_OUTPUT In ) : COLOR
{
	//return float4(1,0,0,1);

	float4 vColor = tex2D( DiffuseMap, In.vTexCoord0 );
	float3 vSpecColor = tex2D( SpecularMap, In.vTexCoord0 ).rgb;
	float3 vNormal = float3(0, 0, 1.0);
		
	// put in special terrain color
	// TODO: check blend equation with photoshop.
	vColor.rgb = lerp(vColor.rgb, TerrainColor.rgb, vSpecColor.b);
		
	//float3 kaka = TerrainColor.rgb * vSpecColor.b;
	//vColor.rgb += kaka;
	//vColor.rgb = vSpecColor.bbb;
	//vColor.rgb = kaka;//lerp(vColor.rgb, TerrainColor.rgb, vSpecColor.b);
	//vColor.rgb = lerp(vColor.rgb,kaka, vSpecColor.b);

	float3 vLightDirection = normalize(In.LightDirection.xyz);
	
	float  NdotL = 1;//max(0.7, dot( vNormal, vLightDirection ) );
	NdotL *= vSpecColor.g;
			
	#ifdef LIGHTMODEL_WRAP
	float diffuse = saturate((NdotL + WRAP) / (1 + WRAP)) * INTENSITY;
	#endif
	#ifdef LIGHTMODEL_HALFLAMBERT
	float diffuse = pow(0.5 * NdotL + 0.5, 2) * INTENSITY;
	#endif
	#ifdef LIGHTMODEL_PHONG
	float diffuse = NdotL * INTENSITY;
	#endif

	float specular = In.Specular * vSpecColor.r * vSpecColor.g;
	
#ifdef DEBUG_SHOW_SPECULARMAP
	return float4(tex2D( SpecularMap, In.vTexCoord0 ).r * float3(1,1,1), 1.0);   // specularity
#endif
#ifdef DEBUG_SHOW_TEXCOORDS
	return float4(In.vTexCoord0.xy, 0.0, 1.0);                     // texture coordinates
#endif
	
#ifdef DEBUG_ONLY_DIFFUSE
	return float4(float3(1,1,1) * diffuse, vColor.a);
#endif
#ifdef DEBUG_ONLY_SPECULAR
	return float4(float3(1,1,1) * specular, vColor.a);
#endif
#ifdef DEBUG_ONLY_COLORMAP
	return vColor;
#endif

	if ( In.LightDirection.w < 0.3f )
	{
		float vAlpha = 1.2;
		vAlpha += ( In.LightDirection.w*0.5f - 0.3f)*0.7f;
		vAlpha = saturate( vAlpha );	
		vAlpha *= vAlpha;
		vColor.a = vAlpha;
	}

	return float4(vColor.rgb /* vColor.a*/ * diffuse + specular, 1 ); // normal

}

float4 SkinnedAvatarPSTracks( VS_OUTPUT In ) : COLOR
{
	float t = frac(Time * TRACK_SPEED);
	float2 Tex = float2(In.vTexCoord0.x, In.vTexCoord0.y + t);
	float4 vColor = tex2D( DiffuseMap, Tex );
	
	return float4(vColor.rgb, vColor.a); // normal
}


VS_OUTPUT StaticAvatarVS(const VS_INPUT v )
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	
	float4 vPosition = mul(v.vPosition, WorldMatrix);
	
	float3 vLightDirection = normalize(vPosition - CameraPosition );
	
	float3 skinnedNormal  = normalize(v.vNormal);
	float4 skinnedTangent = normalize(v.vTangent);
	float3 binormal = cross(skinnedTangent.xyz, skinnedNormal.xyz ) * v.vTangent.w;
	normalize(binormal);
	
	// transform light direction into tangent space
	float3x3 matTBN = float3x3(skinnedTangent.xyz,
	                           binormal,
							   skinnedNormal.xyz);
	Out.LightDirection.xyz = mul(matTBN, -vLightDirection);
	
	Out.vPosition = mul(vPosition, ViewProjectionMatrix );
	Out.vTexCoord0 = v.vTexCoord0;
	
	
	float3 E = mul(matTBN, normalize(vPosition - CameraPosition ));
	float3 H = normalize(E - vLightDirection); 				//half angle vector
	Out.Specular = pow( max(0, dot(skinnedNormal.xyz, H) ), SpecularPower ) * Specularity * INTENSITY;
	
	return Out;
}


/////////////////////////////////////////////////////

technique Standard
{
	pass p0
	{
		ZENABLE = True;
		ZWRITEENABLE = True;
		ALPHABLENDENABLE = True;
		ALPHATESTENABLE = False;
		
		MipMapLodBias[0] = -0.8;
		
		VertexShader = compile vs_2_0 SkinnedAvatarVS();
		PixelShader = compile ps_2_0 SkinnedAvatarPS();
	}
}

technique Standard_Static
{
	pass p0
	{
		VertexShader = compile vs_2_0 StaticAvatarVS();
		PixelShader = compile ps_2_0 SkinnedAvatarPS();
	}
}

technique TexAnim
{
	pass p0
	{
		VertexShader = compile vs_2_0 SkinnedAvatarVS();
		PixelShader = compile ps_2_0 SkinnedAvatarPSTracks();
	}
}