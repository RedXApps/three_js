/*
 In options, we can specify:
 * Texture parameters for an auto-generated target texture
 * depthBuffer/stencilBuffer: Booleans to indicate if we should generate these buffers
*/
// import "package:universal_html/html.dart";

part of three_renderers;

class RenderTarget with EventDispatcher {
  late int width;
  late int height;
  int depth = 1;

  late bool depthBuffer;
  late bool resolveDepthBuffer;
  late bool resolveStencilBuffer;
  bool isWebGLCubeRenderTarget = false;
  bool isWebGL3DRenderTarget = false;
  bool isWebGLArrayRenderTarget = false;
  bool isXRRenderTarget = false;

  List<Texture> textures = [];
  late Texture texture;
  late Vector4 scissor;
  late bool scissorTest;
  late Vector4 viewport;

  late bool stencilBuffer;
  DepthTexture? depthTexture;

  late int _samples;
  late RenderTargetOptions options;

  int get samples => _samples;

  set samples(int value) {
    console.warning("Important warn: make sure set samples before setRenderTarget  ");
    _samples = value;
  }

  RenderTarget(this.width, this.height, [RenderTargetOptions? options]):super(){
    scissor = Vector4(0, 0, width.toDouble(), height.toDouble());
    scissorTest = false;

    viewport = Vector4(0, 0, width.toDouble(), height.toDouble());

    this.options = options ?? RenderTargetOptions();

    final image = ImageElement(width: width, height: height, depth: 1);

    texture = Texture(
      image, 
      this.options.mapping, 
      this.options.wrapS, 
      this.options.wrapT, 
      this.options.magFilter,
      this.options.minFilter, 
      this.options.format, 
      this.options.type, 
      this.options.anisotropy, 
      this.options.encoding
    );
    
    texture.flipY = false;
    texture.generateMipmaps = this.options.generateMipmaps;
    texture.internalFormat = this.options.internalFormat;
    //texture.minFilter = this.options.minFilter != null ? this.options.minFilter! : LinearFilter;
		textures = [];

		final count = this.options.count;
		for (int i = 0; i < count; i ++ ) {
			textures.add(texture.clone());
			textures[i].isRenderTargetTexture = true;
		}

    depthBuffer = this.options.depthBuffer != null ? this.options.depthBuffer! : true;
    stencilBuffer = this.options.stencilBuffer;

		resolveDepthBuffer = this.options.resolveDepthBuffer;
		resolveStencilBuffer = this.options.resolveStencilBuffer;

    depthTexture = this.options.depthTexture;

    _samples = (options != null && options.samples != null) ? options.samples! : 0;
  }

  RenderTarget clone() {
    throw ("RenderTarget clone need implemnt ");
  }

  RenderTarget copy(RenderTarget source){
		height = source.height;
		depth = source.depth;

		scissor.setFrom( source.scissor );
		scissorTest = source.scissorTest;

		viewport.setFrom( source.viewport );

		textures.length = 0;

		for (int i = 0, il = source.textures.length; i < il; i ++ ) {
			textures[ i ] = source.textures[ i ].clone();
			textures[ i ].isRenderTargetTexture = true;
		}

		// ensure image object is not shared, see #20328

		final image = source.texture.image;
		texture.source = Source( image );

		depthBuffer = source.depthBuffer;
		stencilBuffer = source.stencilBuffer;

		resolveDepthBuffer = source.resolveDepthBuffer;
		resolveStencilBuffer = source.resolveStencilBuffer;

		if ( source.depthTexture != null ) depthTexture = source.depthTexture!.clone();

		samples = source.samples;

		return this;
  }

  void setSize(int width, int height, [int depth = 1]) {
    if (this.width != width || this.height != height || this.depth != depth) {
      this.width = width;
      this.height = height;
      this.depth = depth;

      texture.image!.width = width;
      texture.image!.height = height;
      texture.image!.depth = depth;

      dispose();
    }

    viewport.setValues(0, 0, width.toDouble(), height.toDouble());
    scissor.setValues(0, 0, width.toDouble(), height.toDouble());
  }

  bool is3D() {
    throw ("RenderTarget is3D need implemnt ");
  }

  void dispose() {
    dispatchEvent(Event(type: "dispose"));
  }
}

class WebGLRenderTarget extends RenderTarget {
  bool isWebGLRenderTarget = true;
  WebGLRenderTarget(super.width, super.height, [super.options]);

  @override
  WebGLRenderTarget clone() {
    return WebGLRenderTarget(width, height, options).copy(this);
  }

  @override
  WebGLRenderTarget copy(RenderTarget source) {
    super.copy(source);
    return this;
  }

  @override
  bool is3D() {
    return texture is Data3DTexture || texture is DataArrayTexture;
  }
}

class RenderTargetOptions {
  int? wrapS;
  int? wrapT;
  int? magFilter;
  int? minFilter;
  int? format;
  int? type;
  int? anisotropy;
  bool? depthBuffer;
  int? mapping;

  bool stencilBuffer = false;
  bool generateMipmaps = false;
  DepthTexture? depthTexture;
  int? encoding;

  bool useMultisampleRenderToTexture = false;
  bool ignoreDepth = false;
  bool useRenderToTexture = false;

  int? samples;
  int? internalFormat;
  int count = 0;

  bool resolveDepthBuffer = false;
  bool resolveStencilBuffer = false;

  RenderTargetOptions([Map<String, dynamic>? json]) {
    json ??= {};
    if (json["wrapS"] != null) {
      wrapS = json["wrapS"];
    }
    if(json['count'] != null){
      count = json['count'];
    }
    if(json['resolveDepthBuffer'] != null){
      count = json['resolveDepthBuffer'];
    }
    if(json['resolveStencilBuffer'] != null){
      count = json['resolveStencilBuffer'];
    }
    if(json['internalFormat'] != null){
      internalFormat = json['internalFormat'];
    }
    if (json["wrapT"] != null) {
      wrapT = json["wrapT"];
    }
    if (json["magFilter"] != null) {
      magFilter = json["magFilter"];
    }
    if (json["minFilter"] != null) {
      minFilter = json["minFilter"];
    }
    if (json["format"] != null) {
      format = json["format"];
    }
    if (json["type"] != null) {
      type = json["type"];
    }
    if (json["anisotropy"] != null) {
      anisotropy = json["anisotropy"];
    }
    if (json["depthBuffer"] != null) {
      depthBuffer = json["depthBuffer"];
    }
    if (json["mapping"] != null) {
      mapping = json["mapping"];
    }
    if (json["generateMipmaps"] != null) {
      generateMipmaps = json["generateMipmaps"];
    }
    if (json["depthTexture"] != null) {
      depthTexture = json["depthTexture"];
    }
    if (json["encoding"] != null) {
      encoding = json["encoding"];
    }
    if (json["useMultisampleRenderToTexture"] != null) {
      useMultisampleRenderToTexture = json["useMultisampleRenderToTexture"];
    }
    if (json["ignoreDepth"] != null) {
      ignoreDepth = json["ignoreDepth"];
    }
    if (json["useRenderToTexture"] != null) {
      useRenderToTexture = json["useRenderToTexture"];
    }

    samples = json["samples"];
  }

  Map<String, dynamic> toJson() {
    return {
      "wrapS": wrapS,
      "wrapT": wrapT,
      "magFilter": magFilter,
      "minFilter": minFilter,
      'internalFormat': internalFormat,
      "format": format,
      'count': count,
      "type": type,
      'resolveStencilBuffer': resolveStencilBuffer,
      'resolveDepthBuffer': resolveDepthBuffer,
      "anisotropy": anisotropy,
      "depthBuffer": depthBuffer,
      "mapping": mapping,
      "stencilBuffer": stencilBuffer,
      "generateMipmaps": generateMipmaps,
      "depthTexture": depthTexture,
      "encoding": encoding,
      "useMultisampleRenderToTexture": useMultisampleRenderToTexture,
      "ignoreDepth": ignoreDepth,
      "useRenderToTexture": useRenderToTexture,
      "samples": samples
    };
  }
}
