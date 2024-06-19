part of three_webgl;

class WebGLPrograms {
  final shaderIDs = {
    "MeshDepthMaterial": 'depth',
    "MeshDistanceMaterial": 'distanceRGBA',
    "MeshNormalMaterial": 'normal',
    "MeshBasicMaterial": 'basic',
    "MeshLambertMaterial": 'lambert',
    "MeshPhongMaterial": 'phong',
    "MeshToonMaterial": 'toon',
    "MeshStandardMaterial": 'physical',
    "MeshPhysicalMaterial": 'physical',
    "MeshMatcapMaterial": 'matcap',
    "LineBasicMaterial": 'basic',
    "LineDashedMaterial": 'dashed',
    "PointsMaterial": 'points',
    "ShadowMaterial": 'shadow',
    "SpriteMaterial": 'sprite'
  };

  WebGLRenderer renderer;
  WebGLCubeMaps cubemaps;
  WebGLCubeUVMaps cubeuvmaps;
  WebGLExtensions extensions;
  WebGLCapabilities capabilities;
  WebGLBindingStates bindingStates;
  WebGLClipping clipping;

  final _programLayers = Layers();
  final _customShaders = WebGLShaderCache();
  List<WebGLProgram> programs = [];
  final List<int> _activeChannels = [];

  late bool logarithmicDepthBuffer;
  late bool vertexTextures;
  late String precision;

  WebGLPrograms(this.renderer, this.cubemaps, this.cubeuvmaps, this.extensions, this.capabilities, this.bindingStates, this.clipping) {
    logarithmicDepthBuffer = capabilities.logarithmicDepthBuffer;
    vertexTextures = capabilities.vertexTextures;

    precision = capabilities.precision;
  }

	String getChannel(int value ) {
		_activeChannels.add( value );
		if ( value == 0 ) return 'uv';
		return 'uv$value';
	}

  WebGLParameters getParameters(Material material, LightState lights, List<Light> shadows, Scene scene, Object3D object) {
    final fog = scene.fog;
    final geometry = object.geometry;
    final environment = material is MeshStandardMaterial ? scene.environment : null;

    Texture? envMap;
    if (material is MeshStandardMaterial) {
      envMap = cubeuvmaps.get(material.envMap ?? environment);
    } else {
      envMap = cubemaps.get(material.envMap ?? environment);
    }

    final envMapCubeUVHeight = (envMap != null) && (envMap.mapping == CubeUVReflectionMapping) ? envMap.image?.height : null;

    final shaderID = shaderIDs[material.shaderID];

    // heuristics to create shader parameters according to lights in the scene
    // (not to blow over maxLights budget)

    if (material.precision != null) {
      precision = capabilities.getMaxPrecision(material.precision);

      if (precision != material.precision) {
        console.warning('WebGLProgram.getParameters: ${material.precision} not supported, using $precision instead.');
      }
    }

    final morphAttribute = geometry?.morphAttributes["position"] ?? geometry?.morphAttributes["normal"] ?? geometry?.morphAttributes["color"];
    final morphTargetsCount = (morphAttribute != null) ? morphAttribute.length : 0;

    int morphTextureStride = 0;

    if (geometry?.morphAttributes["position"] != null) morphTextureStride = 1;
    if (geometry?.morphAttributes["normal"] != null) morphTextureStride = 2;
    if (geometry?.morphAttributes["color"] != null) morphTextureStride = 3;

    //

    String? vertexShader, fragmentShader;
    dynamic customVertexShaderID;
    dynamic customFragmentShaderID;

    if (shaderID != null) {
      final shader = shaderLib[shaderID];
      vertexShader = shader["vertexShader"];
      fragmentShader = shader["fragmentShader"];
    } else {
      vertexShader = material.vertexShader;
      fragmentShader = material.fragmentShader;

      _customShaders.update(material);

      customVertexShaderID = _customShaders.getVertexShaderID(material);
      customFragmentShaderID = _customShaders.getFragmentShaderID(material);
    }

    // print(" WebGLPrograms material : ${material.type} ${material.shaderID} ${material.id} object: ${object.type} ${object.id} shaderID: ${shaderID} vertexColors: ${material.vertexColors} ");

    final currentRenderTarget = renderer.getRenderTarget();

    final useAlphaTest = material.alphaTest > 0;
    final useClearcoat = material.clearcoat > 0;

    final parameters = WebGLParameters.create();

    parameters.shaderID = shaderID;
    parameters.shaderType = material.type;
    parameters.shaderName = material.name;

    parameters.vertexShader = vertexShader!;
    parameters.fragmentShader = fragmentShader!;
    parameters.defines = material.defines;

    parameters.customVertexShaderID = customVertexShaderID;
    parameters.customFragmentShaderID = customFragmentShaderID;

    parameters.isRawShaderMaterial = material is RawShaderMaterial;
    parameters.glslVersion = material.glslVersion;

    parameters.precision = precision;
    parameters.batching = object is BatchedMesh;
    parameters.instancing = object is InstancedMesh;
    parameters.instancingColor = object is InstancedMesh && object.instanceColor != null;
    parameters.instancingMorph = object is InstancedMesh && object.morphTexture != null;

    parameters.supportsVertexTextures = vertexTextures;
    parameters.outputColorSpace = ( currentRenderTarget == null ) ? renderer.outputColorSpace : ( currentRenderTarget.isXRRenderTarget? currentRenderTarget.texture.colorSpace : LinearSRGBColorSpace);
    parameters.alphaToCoverage = !!material.alphaToCoverage;

    parameters.map = material.map != null;
    parameters.matcap = material.matcap != null;
    parameters.envMap = envMap != null;
    parameters.envMapMode = envMap?.mapping;
    parameters.envMapCubeUVHeight = envMapCubeUVHeight;
    parameters.lightMap = material.lightMap != null;
    parameters.aoMap = material.aoMap != null;
    parameters.emissiveMap = material.emissiveMap != null;
    parameters.bumpMap = material.bumpMap != null;
    parameters.normalMap = material.normalMap != null;

    parameters.normalMapObjectSpace = material.normalMapType == ObjectSpaceNormalMap;
    parameters.normalMapTangentSpace = material.normalMapType == TangentSpaceNormalMap;
    parameters.roughnessMap = material.roughnessMap != null;
    parameters.metalnessMap = material.metalnessMap != null;
      
    parameters.anisotropy =  material is MeshPhysicalMaterial && material.anisotropy > 0;
    parameters.anisotropyMap = material is MeshPhysicalMaterial && material.anisotropy > 0 && material.anisotropyMap != null;

    parameters.clearcoat = useClearcoat;
    parameters.clearcoatMap = useClearcoat && material.clearcoatMap != null;
    parameters.clearcoatRoughnessMap = useClearcoat && material.clearcoatRoughnessMap != null;
    parameters.clearcoatNormalMap = useClearcoat && material.clearcoatNormalMap != null;

    parameters.dispersion = material is MeshPhysicalMaterial && material.dispersion > 0;

    parameters.iridescence = material is MeshPhysicalMaterial && material.iridescence > 0;
    parameters.iridescenceMap = material is MeshPhysicalMaterial && material.iridescence > 0 && material.iridescenceMap != null;
    parameters.iridescenceThicknessMap = material is MeshPhysicalMaterial && material.iridescence > 0 && material.iridescenceThicknessMap != null;

    parameters.sheen = material.sheen > 0;
    parameters.sheenColorMap = material.sheenColorMap != null;
    parameters.sheenRoughnessMap = material.sheenRoughnessMap != null;

    parameters.specularMap = material.specularMap != null;
    parameters.specularIntensityMap = material.specularIntensityMap != null;
    parameters.specularColorMap = material.specularColorMap != null;

    parameters.transmission = material.transmission > 0;
    parameters.transmissionMap = material.transmissionMap != null;
    parameters.thicknessMap = material.thicknessMap != null;

    parameters.gradientMap = material.gradientMap != null;

    parameters.opaque = material.transparent == false && material.blending == NormalBlending;

    parameters.alphaMap = material.alphaMap != null;
    parameters.alphaTest = useAlphaTest;
    parameters.alphaHash = material.alphaHash;

    parameters.combine = material.combine;

    parameters.mapUv = material.map ==null?null: getChannel(material.map!.channel);
    parameters.aoMapUv = material.aoMap ==null?null: getChannel( material.aoMap!.channel );
    parameters.lightMapUv = material.lightMap ==null?null: getChannel( material.lightMap!.channel );
    parameters.bumpMapUv = material.bumpMap ==null?null: getChannel( material.bumpMap!.channel );
    parameters.normalMapUv = material.normalMap ==null?null: getChannel( material.normalMap!.channel );
    parameters.displacementMapUv = material.displacementMap ==null?null: getChannel( material.displacementMap!.channel );
    parameters.emissiveMapUv = material.emissiveMap ==null?null: getChannel( material.emissiveMap!.channel );

    parameters.metalnessMapUv = material.metalnessMap ==null?null: getChannel( material.metalnessMap!.channel );
    parameters.roughnessMapUv = material.roughnessMap ==null?null: getChannel( material.roughnessMap!.channel );

    parameters.anisotropyMapUv = material.anisotropyMap==null?null:getChannel( material.anisotropyMap!.channel );

    parameters.clearcoatMapUv = material.clearcoatMap ==null?null: getChannel( material.clearcoatMap!.channel );
    parameters.clearcoatNormalMapUv = material.clearcoatNormalMap ==null?null: getChannel( material.clearcoatNormalMap!.channel );
    parameters.clearcoatRoughnessMapUv = material.clearcoatRoughnessMap ==null?null: getChannel( material.clearcoatRoughnessMap!.channel );

    parameters.iridescenceMapUv = material.iridescenceMap ==null?null: getChannel( material.iridescenceMap!.channel );
    parameters.iridescenceThicknessMapUv = material.iridescenceThicknessMap ==null?null: getChannel( material.iridescenceThicknessMap!.channel );

    parameters.sheenColorMapUv = material.sheenColorMap ==null?null: getChannel( material.sheenColorMap!.channel );
    parameters.sheenRoughnessMapUv = material.sheenRoughnessMap ==null?null: getChannel( material.sheenRoughnessMap!.channel );

    parameters.specularMapUv = material.specularMap ==null?null: getChannel( material.specularMap!.channel );
    parameters.specularColorMapUv = material.specularColorMap ==null?null: getChannel( material.specularColorMap!.channel );
    parameters.specularIntensityMapUv = material.specularIntensityMap ==null?null: getChannel( material.specularIntensityMap!.channel );

    parameters.transmissionMapUv = material.transmissionMap ==null?null: getChannel( material.transmissionMap!.channel );
    parameters.thicknessMapUv = material.thicknessMap ==null?null: getChannel( material.thicknessMap!.channel );

    parameters.alphaMapUv = material.alphaMap ==null?null: getChannel( material.alphaMap!.channel );

    parameters.vertexTangents = (material.normalMap != null && geometry != null && geometry.attributes["tangent"] != null);
    parameters.vertexColors = material.vertexColors;
    parameters.vertexAlphas = material.vertexColors == true &&
        geometry != null &&
        geometry.attributes["color"] != null &&
        geometry.attributes["color"].itemSize == 4;

    parameters.pointsUvs = object is Points && geometry?.attributes['uv'] != null && ( material.map != null || material.alphaMap != null );


    parameters.fog = fog != null;
    parameters.useFog = material.fog;
    parameters.fogExp2 = (fog != null && fog.isFogExp2);

    parameters.flatShading = material.flatShading;

    parameters.sizeAttenuation = material.sizeAttenuation;
    parameters.logarithmicDepthBuffer = logarithmicDepthBuffer;

    parameters.skinning = object is SkinnedMesh;

    parameters.morphTargets = geometry != null && geometry.morphAttributes["position"] != null;
    parameters.morphNormals = geometry != null && geometry.morphAttributes["normal"] != null;
    parameters.morphColors = geometry != null && geometry.morphAttributes["color"] != null;
    parameters.morphTargetsCount = morphTargetsCount;
    parameters.morphTextureStride = morphTextureStride;

    parameters.numDirLights = lights.directional.length;
    parameters.numPointLights = lights.point.length;
    parameters.numSpotLights = lights.spot.length;
    parameters.numSpotLightMaps = lights.spotLightMap.length;
    parameters.numRectAreaLights = lights.rectArea.length;
    parameters.numHemiLights = lights.hemi.length;

    parameters.numDirLightShadows = lights.directionalShadowMap.length;
    parameters.numPointLightShadows = lights.pointShadowMap.length;
    parameters.numSpotLightShadows = lights.spotShadowMap.length;
    parameters.numSpotLightShadowsWithMaps = lights.numSpotLightShadowsWithMaps;

    parameters.numLightProbes = lights.numLightProbes;

    parameters.numClippingPlanes = clipping.numPlanes;
    parameters.numClipIntersection = clipping.numIntersection;

    parameters.dithering = material.dithering;

    parameters.shadowMapEnabled = renderer.shadowMap.enabled && shadows.isNotEmpty;
    parameters.shadowMapType = renderer.shadowMap.type;

    parameters.toneMapping = material.toneMapped ? renderer.toneMapping : NoToneMapping;
    parameters.useLegacyLights = renderer.useLegacyLights;

    parameters.decodeVideoTexture = material.map != null && (material.map is VideoTexture) && (material.map!.encoding == sRGBEncoding);

    parameters.premultipliedAlpha = material.premultipliedAlpha;

    parameters.doubleSided = material.side == DoubleSide;
    parameters.flipSided = material.side == BackSide;

    parameters.useDepthPacking = material.depthPacking != null;
    parameters.depthPacking = material.depthPacking ?? 0;

    parameters.index0AttributeName = material.index0AttributeName;

    parameters.extensionClipCullDistance = material.extensions != null && material.extensions?["clipCullDistance"] == true && extensions.has( 'WEBGL_clip_cull_distance' );
    parameters.extensionMultiDraw = material.extensions != null && material.extensions?["multiDraw"] == true && extensions.has( 'WEBGL_multi_draw' );

    parameters.customProgramCacheKey = material.customProgramCacheKey() ?? "";

		parameters.vertexUv1s = _activeChannels.contains( 1 );
		parameters.vertexUv2s = _activeChannels.contains( 2 );
		parameters.vertexUv3s = _activeChannels.contains( 3 );

    _activeChannels.clear();

    return parameters;
  }

  String getProgramCacheKey(WebGLParameters parameters) {
    List<dynamic> array = [];

    if (parameters.shaderID != null) {
      array.add(parameters.shaderID!);
    } else {
      array.add(parameters.customVertexShaderID);
      array.add(parameters.customFragmentShaderID);
    }

    if (parameters.defines != null) {
      for (final name in parameters.defines!.keys) {
        array.add(name);
        array.add(parameters.defines![name].toString());
      }
    }

    if (parameters.isRawShaderMaterial == false) {
      getProgramCacheKeyParameters(array, parameters);
      getProgramCacheKeyBooleans(array, parameters);

      array.add(renderer.outputEncoding.toString());
    }

    array.add(parameters.customProgramCacheKey);

    return array.join();
  }

  void getProgramCacheKeyParameters(array, WebGLParameters parameters) {
		array.add( parameters.precision );
		array.add( parameters.outputColorSpace );
		array.add( parameters.envMapMode );
		array.add( parameters.envMapCubeUVHeight );
		array.add( parameters.mapUv );
		array.add( parameters.alphaMapUv );
		array.add( parameters.lightMapUv );
		array.add( parameters.aoMapUv );
		array.add( parameters.bumpMapUv );
		array.add( parameters.normalMapUv );
		array.add( parameters.displacementMapUv );
		array.add( parameters.emissiveMapUv );
		array.add( parameters.metalnessMapUv );
		array.add( parameters.roughnessMapUv );
		array.add( parameters.anisotropyMapUv );
		array.add( parameters.clearcoatMapUv );
		array.add( parameters.clearcoatNormalMapUv );
		array.add( parameters.clearcoatRoughnessMapUv );
		array.add( parameters.iridescenceMapUv );
		array.add( parameters.iridescenceThicknessMapUv );
		array.add( parameters.sheenColorMapUv );
		array.add( parameters.sheenRoughnessMapUv );
		array.add( parameters.specularMapUv );
		array.add( parameters.specularColorMapUv );
		array.add( parameters.specularIntensityMapUv );
		array.add( parameters.transmissionMapUv );
		array.add( parameters.thicknessMapUv );
		array.add( parameters.combine );
		array.add( parameters.fogExp2 );
		array.add( parameters.sizeAttenuation );
		array.add( parameters.morphTargetsCount );
		array.add( parameters.morphAttributeCount );
		array.add( parameters.numDirLights );
		array.add( parameters.numPointLights );
		array.add( parameters.numSpotLights );
		array.add( parameters.numSpotLightMaps );
		array.add( parameters.numHemiLights );
		array.add( parameters.numRectAreaLights );
		array.add( parameters.numDirLightShadows );
		array.add( parameters.numPointLightShadows );
		array.add( parameters.numSpotLightShadows );
		array.add( parameters.numSpotLightShadowsWithMaps );
		array.add( parameters.numLightProbes );
		array.add( parameters.shadowMapType );
		array.add( parameters.toneMapping );
		array.add( parameters.numClippingPlanes );
		array.add( parameters.numClipIntersection );
		array.add( parameters.depthPacking );
  }

  void getProgramCacheKeyBooleans(List array, WebGLParameters parameters) {

		_programLayers.disableAll();

		if ( parameters.supportsVertexTextures )_programLayers.enable( 0 );
		if ( parameters.instancing )_programLayers.enable( 1 );
		if ( parameters.instancingColor )_programLayers.enable( 2 );
		if ( parameters.instancingMorph )_programLayers.enable( 3 );
		if ( parameters.matcap )_programLayers.enable( 4 );
		if ( parameters.envMap )_programLayers.enable( 5 );
		if ( parameters.normalMapObjectSpace )_programLayers.enable( 6 );
		if ( parameters.normalMapTangentSpace )_programLayers.enable( 7 );
		if ( parameters.clearcoat )_programLayers.enable( 8 );
		if ( parameters.iridescence )_programLayers.enable( 9 );
		if ( parameters.alphaTest )_programLayers.enable( 10 );
		if ( parameters.vertexColors )_programLayers.enable( 11 );
		if ( parameters.vertexAlphas )_programLayers.enable( 12 );
		if ( parameters.vertexUv1s )_programLayers.enable( 13 );
		if ( parameters.vertexUv2s )_programLayers.enable( 14 );
		if ( parameters.vertexUv3s )_programLayers.enable( 15 );
		if ( parameters.vertexTangents )_programLayers.enable( 16 );
		if ( parameters.anisotropy )_programLayers.enable( 17 );
		if ( parameters.alphaHash )_programLayers.enable( 18 );
		if ( parameters.batching )_programLayers.enable( 19 );
		if ( parameters.dispersion )_programLayers.enable( 20 );

		array.add( _programLayers.mask );
		_programLayers.disableAll();

		if ( parameters.fog )_programLayers.enable( 0 );
		if ( parameters.useFog )_programLayers.enable( 1 );
		if ( parameters.flatShading )_programLayers.enable( 2 );
		if ( parameters.logarithmicDepthBuffer )_programLayers.enable( 3 );
		if ( parameters.skinning )_programLayers.enable( 4 );
		if ( parameters.morphTargets )_programLayers.enable( 5 );
		if ( parameters.morphNormals )_programLayers.enable( 6 );
		if ( parameters.morphColors )_programLayers.enable( 7 );
		if ( parameters.premultipliedAlpha )_programLayers.enable( 8 );
		if ( parameters.shadowMapEnabled )_programLayers.enable( 9 );
		if ( parameters.useLegacyLights )_programLayers.enable( 10 );
		if ( parameters.doubleSided )_programLayers.enable( 11 );
		if ( parameters.flipSided )_programLayers.enable( 12 );
		if ( parameters.useDepthPacking )_programLayers.enable( 13 );
		if ( parameters.dithering )_programLayers.enable( 14 );
		if ( parameters.transmission )_programLayers.enable( 15 );
		if ( parameters.sheen )_programLayers.enable( 16 );
		if ( parameters.opaque )_programLayers.enable( 17 );
		if ( parameters.pointsUvs )_programLayers.enable( 18 );
		if ( parameters.decodeVideoTexture )_programLayers.enable( 19 );
		if ( parameters.alphaToCoverage )_programLayers.enable( 20 );

		array.add( _programLayers.mask );
  }

  Map<String, dynamic> getUniforms(Material material) {
    String? shaderID = shaderIDs[material.shaderID];
    Map<String, dynamic> uniforms;

    if (shaderID != null) {
      final shader = shaderLib[shaderID];
      uniforms = cloneUniforms(shader["uniforms"]);
    } else {
      uniforms = material.uniforms;
    }

    return uniforms;
  }

  WebGLProgram? acquireProgram(WebGLParameters parameters, String cacheKey) {
    WebGLProgram? program;

    // Check if code has been already compiled
    for (int p = 0, pl = programs.length; p < pl; p++) {
      final preexistingProgram = programs[p];

      if (preexistingProgram.cacheKey == cacheKey) {
        program = preexistingProgram;
        ++program.usedTimes;

        break;
      }
    }

    if (program == null) {
      program = WebGLProgram(renderer, cacheKey, parameters, bindingStates);
      programs.add(program);
    }

    return program;
  }

  void releaseProgram(WebGLProgram program) {
    if (--program.usedTimes == 0) {
      // Remove from unordered set
      final i = programs.indexOf(program);
      programs[i] = programs[programs.length - 1];
      programs.removeLast();

      // Free WebGL resources
      program.destroy();
    }
  }

  void releaseShaderCache(Material material) {
    _customShaders.remove(material);
  }

  void dispose() {
    _customShaders.dispose();
  }
}
