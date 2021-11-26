class PhongMaterial extends Material {

    constructor(color, specular, lights ,translate, scale, vertexShader, fragmentShader) {
        let lightMVP = lights[0].CalcLightMVP(translate, scale);
        let lightMVP_2 = lights[1].CalcLightMVP(translate,scale);
        let lightIntensity = lights[0].mat.GetIntensity();
        let lightIntensity_2 = lights[1].mat.GetIntensity();

        super({
            // Phong
            'uSampler': { type: 'texture', value: color },
            'uKs': { type: '3fv', value: specular },
            'uLightIntensity': { type: '3fv', value: lightIntensity },
            'uLightIntensity_2': {type: '3fv',value: lightIntensity_2 },

            // Shadow
            'uShadowMap': { type: 'texture', value: lights[0].fbo },
            'uLightMVP': { type: 'matrix4fv', value: lightMVP },
            'uShadowMap_2': {type:'texture', value: lights[1].fbo},
            'uLightMVP_2' : {type:'matrix4fv',value: lightMVP_2},

        }, [], vertexShader, fragmentShader);
    }
}

async function buildPhongMaterial(color, specular, lights, translate, scale, vertexPath, fragmentPath) {


    let vertexShader = await getShaderString(vertexPath);
    let fragmentShader = await getShaderString(fragmentPath);

    return new PhongMaterial(color, specular, lights, translate, scale, vertexShader, fragmentShader);

}