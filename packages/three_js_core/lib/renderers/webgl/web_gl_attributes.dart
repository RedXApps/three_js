part of three_webgl;

class WebGLAttributes {
  RenderingContext gl;

  WeakMap buffers = WeakMap();

  WebGLAttributes(this.gl,);

  Map<String, dynamic> createBuffer(dynamic attribute, int bufferType, {String? name}) {//BufferAttribute<NativeArray<num>>
    final array = attribute.array;
    final usage = attribute.usage;

    dynamic type = WebGL.FLOAT;
    int bytesPerElement = 4;

    final buffer = gl.createBuffer();

    gl.bindBuffer(bufferType, buffer);
    gl.bufferData(bufferType, array, usage);

    attribute.onUploadCallback?.call();

    if (attribute is Float32BufferAttribute) {
      type = WebGL.FLOAT;
      bytesPerElement = Float32List.bytesPerElement;
    } 
    else if (attribute is Float64BufferAttribute) {
      console.error('WebGLAttributes: Unsupported data buffer format: Float64Array.');
    } 
    else if (attribute is Float16BufferAttribute) {
      bytesPerElement = 2;
      type = WebGL.HALF_FLOAT;
    } else if (attribute is Uint16BufferAttribute) {
      bytesPerElement = Uint16List.bytesPerElement;
      type = WebGL.UNSIGNED_SHORT;
    } else if (attribute is Int16BufferAttribute) {
      bytesPerElement = Int16List.bytesPerElement;

      type = WebGL.SHORT;
    } else if (attribute is Uint32BufferAttribute) {
      bytesPerElement = Uint32List.bytesPerElement;

      type = WebGL.UNSIGNED_INT;
    } else if (attribute is Int32BufferAttribute) {
      bytesPerElement = Int32List.bytesPerElement;
      type = WebGL.INT;
    } else if (attribute is Int8BufferAttribute) {
      bytesPerElement = Int8List.bytesPerElement;
      type = WebGL.BYTE;
    } else if (attribute is Uint8BufferAttribute) {
      bytesPerElement = Uint8List.bytesPerElement;
      type = WebGL.UNSIGNED_BYTE;
    }

    return {
      "buffer": buffer,
      "type": type,
      "bytesPerElement": bytesPerElement,
      "array": array,
      "version": attribute.version
    };
  }

  void updateBuffer(Buffer buffer, BufferAttribute attribute, int bufferType) {
    final updateRange = attribute.updateRange;
    print(updateRange);

    gl.bindBuffer(bufferType, buffer);

    if (updateRange!["count"] == -1) {
      // Not using update ranges
      gl.bufferSubData(bufferType, 0, attribute.array);
    }

		// if ( updateRange.length != 0 ) {
		// 	for ( let i = 0, l = updateRanges.length; i < l; i ++ ) {
		// 		const range = updateRanges[ i ];
		// 		gl.bufferSubData( bufferType, range.start * array.BYTES_PER_ELEMENT,
		// 			array, range.start, range.count );
		// 	}

		// 	attribute.clearUpdateRanges();
		// }

    else {
      console.info(" WebGLAttributes.dart gl.bufferSubData need debug confirm.... ");
      gl.bufferSubData(bufferType, updateRange["offset"]! * attribute.itemSize, attribute.array);
      updateRange["count"] = -1; // reset range
    }

    attribute.onUploadCallback?.call();
  }

  dynamic get(BaseBufferAttribute attribute) {
    if (attribute.type == "InterleavedBufferAttribute") {
      return buffers.get(attribute.data);
    } 
    else {
      return buffers.get(attribute);
    }
  }
  void dispose(){
    final len = buffers.keys.toList();
    for(int i = 0; i < len.length;i++){
      if(len[i] is BufferAttribute){
        remove(len[i]);
      }
    }
    buffers.clear();
  }
  void remove(BufferAttribute attribute) {
    if (attribute.type == "InterleavedBufferAttribute") {
      final data = buffers.get(attribute.data);

      if (data) {
        gl.deleteBuffer(data.buffer);

        buffers.delete(attribute.data);
      }
    } else {
      final data = buffers.get(attribute);

      if (data != null) {
        gl.deleteBuffer(data["buffer"]);

        buffers.delete(attribute);
      }
    }
  }

  void update(attribute, bufferType, {String? name}) {
    if (attribute.type == "GLBufferAttribute") {
      final cached = buffers.get(attribute);
      if (cached == null || cached["version"] < attribute.version) {
        buffers.add(key: attribute, value: createBuffer(attribute, bufferType, name: name));
      }
      return;
    }

    if (attribute.type == "InterleavedBufferAttribute") {
      attribute = attribute.data;
    }

    final data = buffers.get(attribute);

    if (data == null && attribute != null) {
      buffers.add(
        key: attribute, 
        value: createBuffer(attribute, bufferType, name: name)
      );
    } 
    else if(data?["version"] != null && data["version"] < attribute.version) {
      updateBuffer(data["buffer"], attribute, bufferType);
      data["version"] = attribute.version;
    }
  }
}
