import 'package:three_js/three_js.dart';


class LineMaterial extends ShaderMaterial {

	LineMaterial([Map<MaterialProperty, dynamic>? parameters]):super(parameters) {
    _init();
    if (parameters != null) {
      if (parameters[MaterialProperty.attributes] != null) {
        console.warning('ShaderMaterial: attributes should now be defined in BufferGeometry instead.');
      }

      setValues(parameters);
    }
	}

  LineMaterial.fromMap([Map<String, dynamic>? parameters]) : super.fromMap(parameters) {
    _init();
    if (parameters != null) {
      if (parameters['attributes'] != null) {
        console.warning('ShaderMaterial: attributes should now be defined in BufferGeometry instead.');
      }

      setValuesFromString(parameters);
    }
  }

  void _init(){
    uniformsLib['line'] = {
      'worldUnits': { 'value': 1.0 },
      'linewidth': { 'value': 1.0 },
      'resolution': { 'value': Vector2( 1.0, 1.0 ) },
      'dashOffset': { 'value': 0.0 },
      'dashScale': { 'value': 1.0 },
      'dashSize': { 'value': 1.0 },
      'gapSize': { 'value': 1.0 } // todo FIX - maybe change to totalSize
    };

    shaderLib[ 'line' ] = {
      'uniforms': UniformsUtils.merge( [
        uniformsLib['common'],
        uniformsLib['fog'],
        uniformsLib['line']
      ] ),

      'vertexShader':
      /* glsl */'''
        #include <common>
        #include <color_pars_vertex>
        #include <fog_pars_vertex>
        #include <logdepthbuf_pars_vertex>
        #include <clipping_planes_pars_vertex>

        uniform float linewidth;
        uniform vec2 resolution;

        attribute vec3 instanceStart;
        attribute vec3 instanceEnd;

        attribute vec3 instanceColorStart;
        attribute vec3 instanceColorEnd;

        #ifdef WORLD_UNITS

          varying vec4 worldPos;
          varying vec3 worldStart;
          varying vec3 worldEnd;

          #ifdef USE_DASH

            varying vec2 vUv;

          #endif

        #else

          varying vec2 vUv;

        #endif

        #ifdef USE_DASH

          uniform float dashScale;
          attribute float instanceDistanceStart;
          attribute float instanceDistanceEnd;
          varying float vLineDistance;

        #endif

        void trimSegment( const in vec4 start, inout vec4 end ) {

          // trim end segment so it terminates between the camera plane and the near plane

          // conservative estimate of the near plane
          float a = projectionMatrix[ 2 ][ 2 ]; // 3nd entry in 3th column
          float b = projectionMatrix[ 3 ][ 2 ]; // 3nd entry in 4th column
          float nearEstimate = - 0.5 * b / a;

          float alpha = ( nearEstimate - start.z ) / ( end.z - start.z );

          end.xyz = mix( start.xyz, end.xyz, alpha );

        }

        void main() {

          #ifdef USE_COLOR

            vColor.xyz = ( position.y < 0.5 ) ? instanceColorStart : instanceColorEnd;

          #endif

          #ifdef USE_DASH

            vLineDistance = ( position.y < 0.5 ) ? dashScale * instanceDistanceStart : dashScale * instanceDistanceEnd;
            vUv = uv;

          #endif

          float aspect = resolution.x / resolution.y;

          // camera space
          vec4 start = modelViewMatrix * vec4( instanceStart, 1.0 );
          vec4 end = modelViewMatrix * vec4( instanceEnd, 1.0 );

          #ifdef WORLD_UNITS

            worldStart = start.xyz;
            worldEnd = end.xyz;

          #else

            vUv = uv;

          #endif

          // special case for perspective projection, and segments that terminate either in, or behind, the camera plane
          // clearly the gpu firmware has a way of addressing this issue when projecting into ndc space
          // but we need to perform ndc-space calculations in the shader, so we must address this issue directly
          // perhaps there is a more elegant solution -- WestLangley

          bool perspective = ( projectionMatrix[ 2 ][ 3 ] == - 1.0 ); // 4th entry in the 3rd column

          if ( perspective ) {

            if ( start.z < 0.0 && end.z >= 0.0 ) {

              trimSegment( start, end );

            } else if ( end.z < 0.0 && start.z >= 0.0 ) {

              trimSegment( end, start );

            }

          }

          // clip space
          vec4 clipStart = projectionMatrix * start;
          vec4 clipEnd = projectionMatrix * end;

          // ndc space
          vec3 ndcStart = clipStart.xyz / clipStart.w;
          vec3 ndcEnd = clipEnd.xyz / clipEnd.w;

          // direction
          vec2 dir = ndcEnd.xy - ndcStart.xy;

          // account for clip-space aspect ratio
          dir.x *= aspect;
          dir = normalize( dir );

          #ifdef WORLD_UNITS

            vec3 worldDir = normalize( end.xyz - start.xyz );
            vec3 tmpFwd = normalize( mix( start.xyz, end.xyz, 0.5 ) );
            vec3 worldUp = normalize( cross( worldDir, tmpFwd ) );
            vec3 worldFwd = cross( worldDir, worldUp );
            worldPos = position.y < 0.5 ? start: end;

            // height offset
            float hw = linewidth * 0.5;
            worldPos.xyz += position.x < 0.0 ? hw * worldUp : - hw * worldUp;

            // don't extend the line if we're rendering dashes because we
            // won't be rendering the endcaps
            #ifndef USE_DASH

              // cap extension
              worldPos.xyz += position.y < 0.5 ? - hw * worldDir : hw * worldDir;

              // add width to the box
              worldPos.xyz += worldFwd * hw;

              // endcaps
              if ( position.y > 1.0 || position.y < 0.0 ) {

                worldPos.xyz -= worldFwd * 2.0 * hw;

              }

            #endif

            // project the worldpos
            vec4 clip = projectionMatrix * worldPos;

            // shift the depth of the projected points so the line
            // segments overlap neatly
            vec3 clipPose = ( position.y < 0.5 ) ? ndcStart : ndcEnd;
            clip.z = clipPose.z * clip.w;

          #else

            vec2 offset = vec2( dir.y, - dir.x );
            // undo aspect ratio adjustment
            dir.x /= aspect;
            offset.x /= aspect;

            // sign flip
            if ( position.x < 0.0 ) offset *= - 1.0;

            // endcaps
            if ( position.y < 0.0 ) {

              offset += - dir;

            } else if ( position.y > 1.0 ) {

              offset += dir;

            }

            // adjust for linewidth
            offset *= linewidth;

            // adjust for clip-space to screen-space conversion // maybe resolution should be based on viewport ...
            offset /= resolution.y;

            // select end
            vec4 clip = ( position.y < 0.5 ) ? clipStart : clipEnd;

            // back to clip space
            offset *= clip.w;

            clip.xy += offset;

          #endif

          gl_Position = clip;

          vec4 mvPosition = ( position.y < 0.5 ) ? start : end; // this is an approximation

          #include <logdepthbuf_vertex>
          #include <clipping_planes_vertex>
          #include <fog_vertex>

        }
        ''',

      'fragmentShader':
      /* glsl */'''
        uniform vec3 diffuse;
        uniform float opacity;
        uniform float linewidth;

        #ifdef USE_DASH

          uniform float dashOffset;
          uniform float dashSize;
          uniform float gapSize;

        #endif

        varying float vLineDistance;

        #ifdef WORLD_UNITS

          varying vec4 worldPos;
          varying vec3 worldStart;
          varying vec3 worldEnd;

          #ifdef USE_DASH

            varying vec2 vUv;

          #endif

        #else

          varying vec2 vUv;

        #endif

        #include <common>
        #include <color_pars_fragment>
        #include <fog_pars_fragment>
        #include <logdepthbuf_pars_fragment>
        #include <clipping_planes_pars_fragment>

        vec2 closestLineToLine(vec3 p1, vec3 p2, vec3 p3, vec3 p4) {

          float mua;
          float mub;

          vec3 p13 = p1 - p3;
          vec3 p43 = p4 - p3;

          vec3 p21 = p2 - p1;

          float d1343 = dot( p13, p43 );
          float d4321 = dot( p43, p21 );
          float d1321 = dot( p13, p21 );
          float d4343 = dot( p43, p43 );
          float d2121 = dot( p21, p21 );

          float denom = d2121 * d4343 - d4321 * d4321;

          float numer = d1343 * d4321 - d1321 * d4343;

          mua = numer / denom;
          mua = clamp( mua, 0.0, 1.0 );
          mub = ( d1343 + d4321 * ( mua ) ) / d4343;
          mub = clamp( mub, 0.0, 1.0 );

          return vec2( mua, mub );

        }

        void main() {

          #include <clipping_planes_fragment>

          #ifdef USE_DASH

            if ( vUv.y < - 1.0 || vUv.y > 1.0 ) discard; // discard endcaps

            if ( mod( vLineDistance + dashOffset, dashSize + gapSize ) > dashSize ) discard; // todo - FIX

          #endif

          float alpha = opacity;

          #ifdef WORLD_UNITS

            // Find the closest points on the view ray and the line segment
            vec3 rayEnd = normalize( worldPos.xyz ) * 1e5;
            vec3 lineDir = worldEnd - worldStart;
            vec2 params = closestLineToLine( worldStart, worldEnd, vec3( 0.0, 0.0, 0.0 ), rayEnd );

            vec3 p1 = worldStart + lineDir * params.x;
            vec3 p2 = rayEnd * params.y;
            vec3 delta = p1 - p2;
            float len = length( delta );
            float norm = len / linewidth;

            #ifndef USE_DASH

              #ifdef USE_ALPHA_TO_COVERAGE

                float dnorm = fwidth( norm );
                alpha = 1.0 - smoothstep( 0.5 - dnorm, 0.5 + dnorm, norm );

              #else

                if ( norm > 0.5 ) {

                  discard;

                }

              #endif

            #endif

          #else

            #ifdef USE_ALPHA_TO_COVERAGE

              // artifacts appear on some hardware if a derivative is taken within a conditional
              float a = vUv.x;
              float b = ( vUv.y > 0.0 ) ? vUv.y - 1.0 : vUv.y + 1.0;
              float len2 = a * a + b * b;
              float dlen = fwidth( len2 );

              if ( abs( vUv.y ) > 1.0 ) {

                alpha = 1.0 - smoothstep( 1.0 - dlen, 1.0 + dlen, len2 );

              }

            #else

              if ( abs( vUv.y ) > 1.0 ) {

                float a = vUv.x;
                float b = ( vUv.y > 0.0 ) ? vUv.y - 1.0 : vUv.y + 1.0;
                float len2 = a * a + b * b;

                if ( len2 > 1.0 ) discard;

              }

            #endif

          #endif

          vec4 diffuseColor = vec4( diffuse, alpha );

          #include <logdepthbuf_fragment>
          #include <color_fragment>

          gl_FragColor = vec4( diffuseColor.rgb, alpha );

          #include <tonemapping_fragment>
          #include <colorspace_fragment>
          #include <fog_fragment>
          #include <premultiplied_alpha_fragment>

        }
        '''
    };
		type = 'LineMaterial';
    uniforms = UniformsUtils.clone( shaderLib[ 'line' ]['uniforms'] );
    vertexShader = shaderLib[ 'line' ]['vertexShader'];
    fragmentShader = shaderLib[ 'line' ]['fragmentShader'];
    clipping = true; // required for clipping support

    defaultAttributeValues = {
      'color': [1.0, 1.0, 1.0],
      'uv': [0.0, 0.0],
      'uv2': [0.0, 0.0]
    };
  }

  // @override
	// get color => uniforms['diffuse']['value'];
  // @override
	// set color( value ) {
	// 	uniforms['diffuse']['value'] = value;
	// }

	get worldUnits => defines?.containsKey('WORLD_UNITS');

	set worldUnits( value ) {

		if ( value == true ) {
			defines?['WORLD_UNITS'] = '';
		} 
    else {
			defines?.remove('WORLD_UNITS');
		}
	}
  @override
	get linewidth => uniforms['linewidth']['value'];
  @override
	set linewidth( value ) {
		if (uniforms['linewidth'] == null) return;
		uniforms['linewidth']['value'] = value;
	}

	get dashed => defines?.containsKey('USE_DASH');

	set dashed( value ) {

		if ((value == true ) != dashed ) {
			needsUpdate = true;
		}

		if ( value == true ) {
			defines?['USE_DASH'] = '';
		} 
    else {
			defines?.remove('USE_DASH');
		}
	}

	get dashScale => uniforms['dashScale']['value'];

	set dashScale( value ) {
		uniforms['dashScale']['value'] = value;
	}
  @override
	get dashSize =>uniforms['dashSize']['value'];
  @override
	set dashSize( value ) {
		uniforms['dashSize']['value'] = value;
	}

	get dashOffset => uniforms['dashOffset']['value'];

	set dashOffset( value ) {
		uniforms['dashOffset']['value'] = value;
	}
  @override
	get gapSize => uniforms['gapSize']['value'];
  @override
	set gapSize( value ) {
		uniforms['gapSize']['value'] = value;
	}
  @override
	get opacity => uniforms['opacity']['value'];
  @override
	set opacity( value ) {
		uniforms['opacity']['value'] = value;
	}

	get resolution => uniforms['resolution']['value'];

	set resolution( value ) {
		uniforms['resolution']['value'].copy( value );
	}

  @override
	get alphaToCoverage => defines?.containsKey('USE_ALPHA_TO_COVERAGE') ?? false;
  @override
	set alphaToCoverage( value ) {
		if (defines == null) return;

		if (( value == true ) != alphaToCoverage ) {
			needsUpdate = true;
		}

		if ( value == true ) {
			defines?['USE_ALPHA_TO_COVERAGE'] = '';
		} 
    else {
			defines?.remove('USE_ALPHA_TO_COVERAGE');
		}
	}
}
