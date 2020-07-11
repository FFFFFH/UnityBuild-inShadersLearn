

    #if !defined(PART5_LIGHTING_INCLUDED)
    #define PART5_LIGHTING_INCLUDED
    
    #include "UnityPBSLighting.cginc" 
    #include "AutoLight.cginc" 


    #endif 

	struct appdata
    {
        float4 vertex : POSITION;
        float3 normal : NORMAL;
        float2 uv : TEXCOORD0;

      

    };

    struct v2f
    {
        float2 uv : TEXCOORD0;
        float4 vertex : SV_POSITION;
        float3 normal : TEXCOORD1;      
        float3 worldPos :TEXCOORD2;
          #if defined(VERTEXLIGHT_ON)
            float3 vertexLightColor : TEXCOORD3;
        #endif
    };

    fixed4 _Tint;
    fixed4 _MainTex_ST;
    float _Smoothness;
    //float4 _SpecularTint;
    float _Metallic;
    sampler2D _MainTex;

    //UnityStandardUtils中DiffuseAndSpecularFromMetallic的具体实现
    inline half _OneMinusReflectivityFromMetallic(half metallic) {
        // We'll need oneMinusReflectivity, so
        //   1-reflectivity = 1-lerp(dielectricSpec, 1, metallic)
        //                  = lerp(1-dielectricSpec, 0, metallic)
        // store (1-dielectricSpec) in unity_ColorSpaceDielectricSpec.a, then
        //   1-reflectivity = lerp(alpha, 0, metallic)
        //                  = alpha + metallic*(0 - alpha)
        //                  = alpha - metallic * alpha
        half oneMinusDielectricSpec = unity_ColorSpaceDielectricSpec.a;
        return oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;
    }

    inline half3 _DiffuseAndSpecularFromMetallic (
        half3 albedo, half metallic,
        out half3 specColor, out half oneMinusReflectivity
    ) {
        specColor = lerp(unity_ColorSpaceDielectricSpec.rgb, albedo, metallic);
        oneMinusReflectivity = _OneMinusReflectivityFromMetallic(metallic);
        return albedo * oneMinusReflectivity;
    }


    //AutoLight中的UNITY_LIGHT_ATTENUATION关于点光源的具体实现
    //这里用了一张1维的衰减纹理存储衰减的值
    // #ifdef POINT
    // uniform sampler2D __LightTexture0;
    // uniform unityShadowCoord4x4 _unity_WorldToLight;
    // #define _UNITY_LIGHT_ATTENUATION(destName, input, worldPos)  
    //     unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz;
    //     fixed destName = (tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr). 
    //         UNITY_ATTEN_CHANNEL * SHADOW_ATTENUATION(input));
    // #endif

    //AutoLight中的UNITY_LIGHT_ATTENUATION关于聚光灯光源的具体实现
    // _LightTexture0是光源遮罩贴图，可以自己指定
    // #ifdef SPOT
    // uniform sampler2D _LightTexture0;
    // uniform unityShadowCoord4x4 unity_WorldToLight;
    // uniform sampler2D _LightTextureB0;
    // inline fixed UnitySpotCookie(unityShadowCoord4 LightCoord) {
    //      return tex2D(_LightTexture0, LightCoord.xy / LightCoord.w + 0.5).w;
    // }
    // inline fixed UnitySpotAttenuate(unityShadowCoord3 LightCoord) {
    //      return tex2D(_LightTextureB0, dot(LightCoord, LightCoord).xx).UNITY_ATTEN_CHANNEL;
    // }
    // #define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) 
    //      unityShadowCoord4 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)); 
    //      fixed destName = (lightCoord.z > 0) * UnitySpotCookie(lightCoord) * 
    //          UnitySpotAttenuate(lightCoord.xyz) * SHADOW_ATTENUATION(input);
    // #endif
    // 
    //AutoLight中的UNITY_LIGHT_ATTENUATION关于带cookie的平行光源的具体实现
    // _LightTexture0是光源遮罩贴图，可以自己指定
    // #ifdef DIRECTIONAL_COOKIE
    // uniform sampler2D _LightTexture0;
    // uniform unityShadowCoord4x4 unity_WorldToLight;
    // #define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) 
    //     unityShadowCoord2 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xy; 
    //     fixed destName = tex2D(_LightTexture0, lightCoord).w * SHADOW_ATTENUATION(input);
    //         
    // #endif

    //AutoLight中的UNITY_LIGHT_ATTENUATION关于带cookie的点光源的具体实现
    //这里cookie贴图_LightTexture0是一张cubemap
    // #ifdef POINT_COOKIE
    // uniform samplerCUBE _LightTexture0;
    // uniform unityShadowCoord4x4 unity_WorldToLight;
    // uniform sampler2D _LightTextureB0;
    // #define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) 
    //     unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; 
    //     fixed destName = tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL *
    //           texCUBE(_LightTexture0, lightCoord).w * SHADOW_ATTENUATION(input);
    // #endif


    //根据光的类型返回相应的UnityLight结构体
    UnityLight CreateLight(v2f i)
    {
        UnityLight light;
        #if defined(POINT) || defined(SPOT) || defined(POINT_COOKIE)
            light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
        #else
            //平行光没有光源位置，所以_WorldSpaceLightPos0.xyz就是光的方向
            light.dir = _WorldSpaceLightPos0.xyz;
        #endif

        float3 lightVec = _WorldSpaceLightPos0.xyz - i.worldPos;
        //计算光衰减，光强随距离增大而减小，如点光源,分母+1是为了防止距离过近是attenuation变得很大
        //float attenuation = 1 / (1 + dot(lightVec,lightVec)); 

        //AutoLight中UNITY_LIGHT_ATTENUATION也是计算光衰减的，但计算方法不太一样
        UNITY_LIGHT_ATTENUATION(attenuation, 0, i.worldPos);

        light.color = _LightColor0.rgb * attenuation;
        light.ndotl = DotClamped(i.normal,light.dir);
        return light;
    }

    //创建环境光，如果存在顶点光源，则作为环境光
    UnityIndirect CreateIndirectLight(v2f i)
    {
        UnityIndirect indirectLight;
        indirectLight.diffuse = 0;
        indirectLight.specular = 0;
        #if defined(VERTEXLIGHT_ON)
            indirectLight.diffuse = i.vertexLightColor;
        #endif
        return indirectLight;
    }

    //UnityCG中Shade4PointLights函数具体实现
    // float3 _Shade4PointLights (
    //     float4 lightPosX, float4 lightPosY, float4 lightPosZ,
    //     float3 lightColor0, float3 lightColor1,
    //     float3 lightColor2, float3 lightColor3,
    //     float4 lightAttenSq, float3 pos, float3 normal) {
    //     // to light vectors
    //     float4 toLightX = lightPosX - pos.x;
    //     float4 toLightY = lightPosY - pos.y;
    //     float4 toLightZ = lightPosZ - pos.z;
    //     // squared lengths
    //     float4 lengthSq = 0;
    //     lengthSq += toLightX * toLightX;
    //     lengthSq += toLightY * toLightY;
    //     lengthSq += toLightZ * toLightZ;
    //     // NdotL
    //     float4 ndotl = 0;
    //     ndotl += toLightX * normal.x;
    //     ndotl += toLightY * normal.y;
    //     ndotl += toLightZ * normal.z;
    //     // correct NdotL 
    //     // rsqrt（x） = 1/ 根号x
    //     float4 corr = rsqrt(lengthSq);
    //     ndotl = max(float4(0,0,0,0), ndotl * corr);
    //     // attenuation
    //     float4 atten = 1.0 / (1.0 + lengthSq * lightAttenSq);
    //     float4 diff = ndotl * atten;
    //     // final color
    //     float3 col = 0;
    //     col += lightColor0 * diff.x;
    //     col += lightColor1 * diff.y;
    //     col += lightColor2 * diff.z;
    //     col += lightColor3 * diff.w;
    //     return col;
    // }


    void ComputeVertexLightColor(inout v2f i)
    {
        #if defined(VERTEXLIGHT_ON)
            // //unity 最多支持四个顶点光源，并用4个float4结果存储这4个光源的位置
            // float3 lightPos = float3(unity_4LightPosX0.x,unity_4LightPosY0.x,unity_4LightPosZ0.x);
            // float3 lightVec = lightPos - i.worldPos;
            // float3 lightDir = normalize(lightVec);
            // float ndotl = DotClamped(i.normal, lightDir);
            // float attenuations = 1 / (1+dot(lightVec,lightVec));
            // //unity_4LightAtten0是UnityShaderVariables中定义的衰减值，应该是用于更平滑的衰减
            // v.vertexLightColor = unity_LightColor[0].rgb * ndotl * attenuations * unity_4LightAtten0.x;

            //Shade4PointLights相当于执行了4次以上的操作并混合
            i.vertexLightColor = Shade4PointLights(
            unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
            unity_LightColor[0].rgb, unity_LightColor[1].rgb,
            unity_LightColor[2].rgb, unity_LightColor[3].rgb,
            unity_4LightAtten0, i.worldPos, i.normal
            );
        #endif
    }

    v2f vert (appdata v)
    {
        v2f o;
        o.vertex = UnityObjectToClipPos(v.vertex);
        o.uv = v.uv;
        //合批后本地空间的法线方向会改变，所以需要变换到世界空间
        //将法线变换到世界空间，如果直接用unity_ObjectToWorld变换，缩放后法线会受影响
        //公式的推导参考<shader入门精要>                
        o.normal = mul(transpose((float3x3)unity_WorldToObject),v.normal);
        o.normal = normalize(o.normal);
        o.worldPos = mul(unity_ObjectToWorld,v.vertex);
        //UnityCG 提供了相同操作的接口 UnityObjectToWorldNormal
        //o.normal = UnityObjectToWorldNormal(v.normal);
        ComputeVertexLightColor(o);
        return o;
    }

 	fixed4 frag (v2f i) : SV_Target
    {
        //不同单位长度的法线经过差值后不能得到单位向量，需要再归一化
        i.normal = normalize(i.normal);

        //也可以在顶点函数计算视角方向并插值，但可能存在过渡不平缓的情况
        float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

        //Blinn-Phong模型，近似模拟Blinn模型
        //避免计算 reflect(-lightDir, i.normal); 
        //reflect 计算公式为： D - 2N(N·D) ,推导过程网上有
        //float3 halfVector = normalize(lightDir + viewDir);

        float3 albedo = tex2D(_MainTex,i.uv).rgb * _Tint.rgb;

        //使用金属工作流时，高光颜色由反射率乘以金属度
        float3 _SpecularTint = albedo * _Metallic;


        //当入射 DotClamped(halfVector,i.normal)表示的是当halfVector与normal重合度
        //越高反射光强度越强
        //金属的镜面反射往往是彩色的，这里用_SpecularTint来模拟
        //float3 specular = _SpecularTint.rgb * lightColor * pow(DotClamped(halfVector,i.normal), _Smoothness * 100);
        
        //保证能量守恒，高光与漫反射相加的和小于等于1，
        //UnityStandardUtils 中定义的 EnergyConservationBetweenDiffuseAndSpecular做的就是相同操作
        // float oneMinusReflectivity = 1 - max(_SpecularTint.r,max(_SpecularTint.g,_SpecularTint.b));
        //albedo *= oneMinusReflectivity;

        float oneMinusReflectivity;
        //oneMinusReflectivity 在方法里面计算并返回
        // albedo = EnergyConservationBetweenDiffuseAndSpecular(
        //     albedo, _SpecularTint.rgb, oneMinusReflectivity
        // );

        //以上得到的 albedo 是的计算过程是简化了的，实际上高光强度和反射率不只与金属度相关，
        //还与颜色空间有关，UnityStandardUtils了提供DiffuseAndSpecularFromMetallic 方法在进行
        //以上操作时还加入了与颜色空间相关的操作
        albedo = _DiffuseAndSpecularFromMetallic(
            albedo, _Metallic, _SpecularTint.rgb, oneMinusReflectivity
        );
        //DotClamped定义在UnityStandardBRDF,等价于 saturate(dot(a,b));
        //float3 diffuse = albedo * lightColor * DotClamped(lightDir, i.normal);

 

        return UNITY_BRDF_PBS(
                albedo, _SpecularTint,
                oneMinusReflectivity, _Smoothness,
                i.normal, viewDir,
                CreateLight(i), CreateIndirectLight(i)
            );

    }