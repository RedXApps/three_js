import 'dart:convert';
import 'package:flutter_gl/flutter_gl.dart';
import '../others/index.dart';
import '../core/event_dispatcher.dart';
import 'package:three_js_math/three_js_math.dart';
import '../core/object_3d.dart';
import '../core/morph_target.dart';
import 'dart:math' as math;

int _bufferGeometryId = 1; // BufferGeometry uses odd numbers as Id

final _bufferGeometrym1 = Matrix4.identity();
final _bufferGeometryobj = Object3D();
final _bufferGeometryoffset = Vector3.zero();
final _bufferGeometrybox = BoundingBox();
final _bufferGeometryboxMorphTargets = BoundingBox();
final _bufferGeometryvector = Vector3.zero();

class BufferGeometry with EventDispatcher {
  int id = _bufferGeometryId += 2;
  String uuid = MathUtils.generateUUID();

  String type = "BufferGeometry";
  BoundingBox? boundingBox;
  String name = "";
  Map<String, dynamic> attributes = {};
  Map<String, List<BufferAttribute>> morphAttributes = {};
  bool morphTargetsRelative = false;
  BoundingSphere? boundingSphere;
  Map<String, int> drawRange = {"start": 0, "count": double.maxFinite.toInt()};
  Map<String, dynamic> userData = {};
  List<Map<String, dynamic>> groups = [];
  BufferAttribute? index;

  late List<MorphTarget> morphTargets;
  late BufferGeometry directGeometry;

  bool elementsNeedUpdate = false;
  bool verticesNeedUpdate = false;
  bool uvsNeedUpdate = false;
  bool normalsNeedUpdate = false;
  bool colorsNeedUpdate = false;
  bool lineDistancesNeedUpdate = false;
  bool groupsNeedUpdate = false;

  late List<Color> colors;
  late List<double> lineDistances;

  Map<String, dynamic>? parameters;

  late int curveSegments;
  //late List<Shape> shapes;

  int? maxInstanceCount;
  int? instanceCount;

  BufferGeometry();

  BufferGeometry.fromJson(Map<String, dynamic> json, Map<String, dynamic> rootJson) {
    uuid = json["uuid"];
    type = json["type"];
  }

  static BufferGeometry castJson(Map<String, dynamic> json, Map<String, dynamic> rootJson) {
    String type = json["type"];

    if (type == "BufferGeometry") {
      return BufferGeometry.fromJson(json, rootJson);
    } 
    // else if (type == "ShapeGeometry") {
    //   return ShapeGeometry.fromJson(json, rootJson);
    // } 
    // else if (type == "ExtrudeGeometry") {
    //   return ExtrudeGeometry.fromJson(json, rootJson);
    // } 
    else {
      throw (" BufferGeometry castJson _type: $type is not support yet ");
    }
  }

  BufferAttribute? getIndex() => index;

  void setIndex(index) {
    if (index is List) {
      final list = index.map<int>((e) => e.toInt()).toList();
      final max = list.getMaxValue();
      if (max != null && max > 65535) {
        this.index = Uint32BufferAttribute(Uint32Array.from(list), 1, false);
      } 
      else {
        this.index = Uint16BufferAttribute(Uint16Array.from(list), 1, false);
      }
    } 
    else {
      this.index = index;
    }
  }

  dynamic getAttribute(Semantic type) {
    return attributes[type.name];
  }
  BufferGeometry setAttribute(Semantic type, attribute) {
    attributes[type.name] = attribute;
    return this;
  }
  BufferGeometry deleteAttribute(Semantic type) {
    attributes.remove(type.name);
    return this;
  }
  bool hasAttribute(Semantic type) {
    return attributes[type.name] != null;
  }

  dynamic getAttributeFromString(String type) {
    return attributes[type];
  }
  BufferGeometry setAttributeFromString(String type, BufferAttribute source) {
    attributes[type] = source;
    return this;
  }
  BufferGeometry deleteAttributeFromString(String type) {
    attributes.remove(type);
    return this;
  }
  bool hasAttributeFromString(String type) {
    return attributes[type] != null;
  }

  void addGroup(int start, int count, [int materialIndex = 0]) {
    groups.add({
      "start": start,
      "count": count,
      "materialIndex": materialIndex,
    });
  }

  void clearGroups() {
    groups = [];
  }

  void setDrawRange(int start, int count) {
    drawRange["start"] = start;
    drawRange["count"] = count;
  }

  void applyMatrix4(Matrix4 matrix) {
    final position = attributes["position"];
    if (position != null) {
      position.applyMatrix4(matrix);
      position.needsUpdate = true;
    }

    final normal = attributes["normal"];

    if (normal != null) {
      final normalMatrix = Matrix3.identity().getNormalMatrix(matrix);

      normal.applyNormalMatrix(normalMatrix);

      normal.needsUpdate = true;
    }

    final tangent = attributes["tangent"];

    if (tangent != null) {
      tangent.transformDirection(matrix);

      tangent.needsUpdate = true;
    }

    if (boundingBox != null) {
      computeBoundingBox();
    }

    if (boundingSphere != null) {
      computeBoundingSphere();
    }
  }

  BufferGeometry applyQuaternion(Quaternion q) {
    m1.makeRotationFromQuaternion(q);
    applyMatrix4(m1);
    return this;
  }

  BufferGeometry rotateX(double angle) {
    // rotate geometry around world x-axis
    _bufferGeometrym1.makeRotationX(angle);
    applyMatrix4(_bufferGeometrym1);
    return this;
  }

  BufferGeometry rotateY(double angle) {
    // rotate geometry around world y-axis
    _bufferGeometrym1.makeRotationY(angle);
    applyMatrix4(_bufferGeometrym1);
    return this;
  }

  BufferGeometry rotateZ(double angle) {
    // rotate geometry around world z-axis
    _bufferGeometrym1.makeRotationZ(angle);
    applyMatrix4(_bufferGeometrym1);
    return this;
  }

  BufferGeometry translate(double x, double y, double z) {
    // translate geometry
    _bufferGeometrym1.makeTranslation(x, y, z);
    applyMatrix4(_bufferGeometrym1);
    return this;
  }

  BufferGeometry translateWithVector3(Vector3 v3) {
    return translate(v3.x, v3.y, v3.z);
  }

  BufferGeometry scale(double x, double y, double z) {
    // scale geometry
    _bufferGeometrym1.makeScale(x, y, z);
    applyMatrix4(_bufferGeometrym1);
    return this;
  }

  BufferGeometry lookAt(Vector3 vector) {
    _bufferGeometryobj.lookAt(vector);
    _bufferGeometryobj.updateMatrix();
    applyMatrix4(_bufferGeometryobj.matrix);
    return this;
  }

  void center() {
    computeBoundingBox();
    boundingBox!.getCenter(_bufferGeometryoffset);
    _bufferGeometryoffset.negate();
    translate(_bufferGeometryoffset.x, _bufferGeometryoffset.y,_bufferGeometryoffset.z);
  }

  BufferGeometry setFromPoints(points) {
    List<double> position = [];

    for (int i = 0, l = points.length; i < l; i++) {
      final point = points[i];

      if (point is Vector2) {
        position.addAll([point.x.toDouble(), point.y.toDouble(), 0.0]);
      } 
      else {
        position.addAll([point.x.toDouble(), point.y.toDouble(), (point.z ?? 0).toDouble()]);
      }
    }

    final array = Float32Array.from(position);
    setAttributeFromString('position', Float32BufferAttribute(array, 3, false));

    return this;
  }

  void computeBoundingBox() {
    boundingBox ??= BoundingBox();

    final position = attributes["position"];
    final morphAttributesPosition = morphAttributes["position"];

    if (position != null && position is GLBufferAttribute) {
      print('THREE.BufferGeometry.computeBoundingBox(): GLBufferAttribute requires a manual bounding box. Alternatively set "mesh.frustumCulled" to "false". $this');

      double infinity = 9999999999.0;

      boundingBox!.set(Vector3(-infinity, -infinity, -infinity),Vector3(infinity, infinity, infinity));

      return;
    }

    if (position != null) {
      boundingBox!.setFromBuffer(position);

      // process morph attributes if present

      if (morphAttributesPosition != null) {
        for (int i = 0, il = morphAttributesPosition.length; i < il; i++) {
          final morphAttribute = morphAttributesPosition[i];
          _bufferGeometrybox.setFromBuffer(morphAttribute);

          if (morphTargetsRelative) {
            _bufferGeometryvector.add2(boundingBox!.min, _bufferGeometrybox.min);
            boundingBox!.expandByPoint(_bufferGeometryvector);

            _bufferGeometryvector.add2(boundingBox!.max, _bufferGeometrybox.max);
            boundingBox!.expandByPoint(_bufferGeometryvector);
          } else {
            boundingBox!.expandByPoint(_bufferGeometrybox.min);
            boundingBox!.expandByPoint(_bufferGeometrybox.max);
          }
        }
      }
    } else {
      boundingBox!.empty();
    }

    // if (boundingBox!.min.x == null ||
    //     boundingBox!.min.y == null ||
    //     boundingBox!.min.z == null) {
    //   print(
    //       'THREE.BufferGeometry.computeBoundingBox(): Computed min/max have NaN values. The "position" attribute is likely to have NaN values. ${this}');
    // }
  }

  void computeBoundingSphere() {
    boundingSphere ??= BoundingSphere();

    final position = attributes["position"];
    final morphAttributesPosition = morphAttributes["position"];

    if (position != null && position is GLBufferAttribute) {
      boundingSphere!.set(Vector3.zero(), 99999999999);

      return;
    }

    if (position != null) {
      // first, find the center of the bounding sphere

      final center = boundingSphere!.center;

      _bufferGeometrybox.setFromBuffer(position);

      // process morph attributes if present

      if (morphAttributesPosition != null) {
        for (int i = 0, il = morphAttributesPosition.length; i < il; i++) {
          final morphAttribute = morphAttributesPosition[i];
          _bufferGeometryboxMorphTargets.setFromBuffer(morphAttribute);

          if (morphTargetsRelative) {
            _bufferGeometryvector.add2(_bufferGeometrybox.min, _bufferGeometryboxMorphTargets.min);
            _bufferGeometrybox.expandByPoint(_bufferGeometryvector);

            _bufferGeometryvector.add2(_bufferGeometrybox.max, _bufferGeometryboxMorphTargets.max);
            _bufferGeometrybox.expandByPoint(_bufferGeometryvector);
          } else {
            _bufferGeometrybox.expandByPoint(_bufferGeometryboxMorphTargets.min);
            _bufferGeometrybox.expandByPoint(_bufferGeometryboxMorphTargets.max);
          }
        }
      }

      _bufferGeometrybox.getCenter(center);

      // second, try to find a boundingSphere with a radius smaller than the
      // boundingSphere of the boundingBox: sqrt(3) smaller in the best case
      double maxRadiusSq = 0;
      for (int i = 0, il = position.count; i < il; i++) {
        _bufferGeometryvector.fromBuffer(position, i);
        maxRadiusSq = math.max(
          maxRadiusSq,
          center.distanceToSquared(_bufferGeometryvector),
        );
      }

      // process morph attributes if present

      if (morphAttributesPosition != null) {
        for (int i = 0, il = morphAttributesPosition.length; i < il; i++) {
          final morphAttribute = morphAttributesPosition[i];
          final morphTargetsRelative = this.morphTargetsRelative;

          for (int j = 0, jl = morphAttribute.count; j < jl; j++) {
            _bufferGeometryvector.fromBuffer(morphAttribute, j);

            if (morphTargetsRelative) {
              _bufferGeometryoffset.fromBuffer(position, j);
              _bufferGeometryvector.add(_bufferGeometryoffset);
            }

            maxRadiusSq = math.max(
              maxRadiusSq,
              center.distanceToSquared(_bufferGeometryvector),
            );
          }
        }
      }

      boundingSphere!.radius = math.sqrt(maxRadiusSq);

      if (boundingSphere?.radius == null) {
        print('THREE.BufferGeometry.computeBoundingSphere(): Computed radius is NaN. The "position" attribute is likely to have NaN values. $this');
      }
    }
  }

  void computeFaceNormals() {
    // backwards compatibility
  }

  void computeTangents() {
    final index = this.index;
    final attributes = this.attributes;

    // based on http://www.terathon.com/code/tangent.html
    // (per vertex tangents)

    if (index == null ||
        attributes["position"] == null ||
        attributes["normal"] == null ||
        attributes["uv"] == null) {
      Console.error('THREE.BufferGeometry: .computeTangents() failed. Missing required attributes (index, position, normal or uv)');
      return;
    }

    final indices = index.array;
    final positions = attributes["position"].array;
    final normals = attributes["normal"].array;
    final uvs = attributes["uv"].array;

    int nVertices = positions.length ~/ 3;

    if (attributes["tangent"] == null) {
      setAttributeFromString('tangent', Float32BufferAttribute(Float32Array(4 * nVertices), 4));
    }

    final tangents = attributes["tangent"].array;

    final List<Vector3> tan1 = [], tan2 = [];

    for (int i = 0; i < nVertices; i++) {
      tan1.add(Vector3.zero());
      tan2.add(Vector3.zero());
    }

    final vA = Vector3.zero(),
        vB = Vector3.zero(),
        vC = Vector3.zero(),
        uvA = Vector2.zero(),
        uvB = Vector2.zero(),
        uvC = Vector2.zero(),
        sdir = Vector3.zero(),
        tdir = Vector3.zero();

    void handleTriangle(int a, int b, int c) {
      vA.fromNativeArray(positions, a * 3);
      vB.fromNativeArray(positions, b * 3);
      vC.fromNativeArray(positions, c * 3);

      uvA.fromNativeArray(uvs, a * 2);
      uvB.fromNativeArray(uvs, b * 2);
      uvC.fromNativeArray(uvs, c * 2);

      vB.sub(vA);
      vC.sub(vA);

      uvB.sub(uvA);
      uvC.sub(uvA);

      double r = 1.0 / (uvB.x * uvC.y - uvC.x * uvB.y);

      // silently ignore degenerate uv triangles having coincident or colinear vertices

      if (!r.isFinite) return;

      sdir.setFrom(vB);
      sdir.scale(uvC.y);
      sdir.addScaled(vC, -uvB.y);
      sdir.scale(r);

      tdir.setFrom(vC);
      tdir.scale(uvB.x);
      tdir.addScaled(vB, -uvC.x);
      tdir.scale(r);

      tan1[a].add(sdir);
      tan1[b].add(sdir);
      tan1[c].add(sdir);

      tan2[a].add(tdir);
      tan2[b].add(tdir);
      tan2[c].add(tdir);
    }

    List<Map<String,dynamic>> groups = this.groups;

    if (groups.isEmpty) {
      groups = [
        {"start": 0, "count": indices.length}
      ];
    }

    for (int i = 0, il = groups.length; i < il; ++i) {
      final group = groups[i];

      final start = group["start"];
      final count = group["count"];

      for (int j = start, jl = start + count; j < jl; j += 3) {
        handleTriangle(
          indices[j + 0].toInt(),
          indices[j + 1].toInt(),
          indices[j + 2].toInt(),
        );
      }
    }

    final tmp = Vector3.zero(), tmp2 = Vector3.zero();
    final n = Vector3.zero(), n2 = Vector3.zero();

    void handleVertex(int v) {
      n.fromNativeArray(normals, v * 3);
      n2.setFrom(n);

      final t = tan1[v];

      // Gram-Schmidt orthogonalize

      tmp.setFrom(t);
      n.scale(n.dot(t));
      tmp.sub(n);
      tmp.normalize();

      // Calculate handedness

      tmp2.cross2(n2, t);
      final test = tmp2.dot(tan2[v]);
      final w = (test < 0.0) ? -1.0 : 1.0;

      tangents[v * 4] = tmp.x;
      tangents[v * 4 + 1] = tmp.y;
      tangents[v * 4 + 2] = tmp.z;
      tangents[v * 4 + 3] = w;
    }

    for (int i = 0, il = groups.length; i < il; ++i) {
      final group = groups[i];

      final start = group["start"];
      final count = group["count"];

      for (int j = start, jl = start + count; j < jl; j += 3) {
        handleVertex(indices[j + 0].toInt());
        handleVertex(indices[j + 1].toInt());
        handleVertex(indices[j + 2].toInt());
      }
    }
  }

  void computeVertexNormals() {
    final index = this.index;
    final positionAttribute = getAttributeFromString('position');

    if (positionAttribute != null) {
      Float32BufferAttribute? normalAttribute = getAttributeFromString('normal');

      if (normalAttribute == null) {
        final array = List<double>.filled(positionAttribute.count * 3, 0);
        normalAttribute = Float32BufferAttribute(Float32Array.from(array), 3, false);
        setAttributeFromString('normal', normalAttribute);
      } 
      else {
        // reset existing normals to zero
        for (int i = 0, il = normalAttribute.count; i < il; i++) {
          normalAttribute.setXYZ(i, 0, 0, 0);
        }
      }

      final pA = Vector3.zero(), pB = Vector3.zero(), pC = Vector3.zero();
      final nA = Vector3.zero(), nB = Vector3.zero(), nC = Vector3.zero();
      final cb = Vector3.zero(), ab = Vector3.zero();

      // indexed elements

      if (index != null) {
        for (int i = 0, il = index.count; i < il; i += 3) {
          final vA = index.getX(i + 0)!.toInt();
          final vB = index.getX(i + 1)!.toInt();
          final vC = index.getX(i + 2)!.toInt();

          pA.fromBuffer(positionAttribute, vA);
          pB.fromBuffer(positionAttribute, vB);
          pC.fromBuffer(positionAttribute, vC);

          cb.sub2(pC, pB);
          ab.sub2(pA, pB);
          cb.cross(ab);

          nA.fromBuffer(normalAttribute, vA);
          nB.fromBuffer(normalAttribute, vB);
          nC.fromBuffer(normalAttribute, vC);

          nA.add(cb);
          nB.add(cb);
          nC.add(cb);

          normalAttribute.setXYZ(vA, nA.x, nA.y, nA.z);
          normalAttribute.setXYZ(vB, nB.x, nB.y, nB.z);
          normalAttribute.setXYZ(vC, nC.x, nC.y, nC.z);
        }
      } 
      else {
        for (int i = 0, il = positionAttribute.count; i < il; i += 3) {
          pA.fromBuffer(positionAttribute, i + 0);
          pB.fromBuffer(positionAttribute, i + 1);
          pC.fromBuffer(positionAttribute, i + 2);

          cb.sub2(pC, pB);
          ab.sub2(pA, pB);
          cb.cross(ab);

          normalAttribute.setXYZ(i + 0, cb.x, cb.y, cb.z);
          normalAttribute.setXYZ(i + 1, cb.x, cb.y, cb.z);
          normalAttribute.setXYZ(i + 2, cb.x, cb.y, cb.z);
        }
      }

      normalizeNormals();

      normalAttribute.needsUpdate = true;
    }
  }

  BufferGeometry merge(BufferGeometry geometry, [int? offset]) {
    // if (!(geometry && geometry.isBufferGeometry)) {
    //   print(
    //       'THREE.BufferGeometry.merge(): geometry not an instance of THREE.BufferGeometry. $geometry');
    //   return;
    // }

    if (offset == null) {
      offset = 0;

      print(
          'THREE.BufferGeometry.merge(): Overwriting original geometry, starting at offset=0. '
          'Use BufferGeometryUtils.mergeBufferGeometries() for lossless merge.');
    }

    final attributes = this.attributes;

    for (String key in attributes.keys) {
      if (geometry.attributes[key] != null) {
        final attribute1 = attributes[key];
        final attributeArray1 = attribute1.array;

        final attribute2 = geometry.attributes[key];
        final attributeArray2 = attribute2.array;

        final attributeOffset = attribute2.itemSize * offset;
        final length = math.min<int>(attributeArray2.length, attributeArray1.length - attributeOffset);

        for (int i = 0, j = attributeOffset; i < length; i++, j++) {
          attributeArray1[j] = attributeArray2[i];
        }
      }
    }

    return this;
  }

  void normalizeNormals() {
    final normals = attributes["normal"];

    for (int i = 0, il = normals.count; i < il; i++) {
      _bufferGeometryvector.fromBuffer(normals, i);
      _bufferGeometryvector.normalize();
      normals.setXYZ(i, _bufferGeometryvector.x, _bufferGeometryvector.y,_bufferGeometryvector.z);
    }
  }

  BufferGeometry toNonIndexed() {
    convertBufferAttribute(attribute, indices) {
      print("BufferGeometry.convertBufferAttribute todo  ");

      final array = attribute.array;
      final itemSize = attribute.itemSize;
      final normalized = attribute.normalized;

      final array2 = Float32Array(indices.length * itemSize);

      int index = 0, index2 = 0;

      for (int i = 0, l = indices.length; i < l; i++) {
        if (attribute is InterleavedBufferAttribute) {
          index = indices[i] * attribute.data!.stride + attribute.offset;
        } else {
          index = indices[i] * itemSize;
        }

        for (int j = 0; j < itemSize; j++) {
          array2[index2++] = array[index++];
        }
      }

      return Float32BufferAttribute(array2, itemSize, normalized);
    }

    //

    if (index == null) {
      print('THREE.BufferGeometry.toNonIndexed(): Geometry is already non-indexed.');
      return this;
    }

    final geometry2 = BufferGeometry();

    final indices = index!.array;
    final attributes = this.attributes;

    // attributes

    for (String name in attributes.keys) {
      final attribute = attributes[name];

      final newAttribute = convertBufferAttribute(attribute, indices);

      geometry2.setAttributeFromString(name, newAttribute);
    }

    // morph attributes

    final morphAttributes = this.morphAttributes;

    for (String name in morphAttributes.keys) {
      List<BufferAttribute> morphArray = [];
      List<BufferAttribute> morphAttribute = morphAttributes[name]!; // morphAttribute: array of Float32BufferAttributes

      for (int i = 0, il = morphAttribute.length; i < il; i++) {
        final attribute = morphAttribute[i];

        final newAttribute = convertBufferAttribute(attribute, indices);

        morphArray.add(newAttribute);
      }

      geometry2.morphAttributes[name] = morphArray;
    }

    geometry2.morphTargetsRelative = morphTargetsRelative;

    // groups

    List<Map<String,dynamic>> groups = this.groups;

    for (int i = 0, l = groups.length; i < l; i++) {
      final group = groups[i];
      geometry2.addGroup(group["start"], group["count"], group["materialIndex"]);
    }

    return geometry2;
  }

  Map<String, dynamic> toJson({Object3dMeta? meta}) {
    Map<String, dynamic> data = {
      "metadata": {
        "version": 4.5,
        "type": 'BufferGeometry',
        "generator": 'BufferGeometry.toJson'
      }
    };

    // standard BufferGeometry serialization

    data["uuid"] = uuid;
    data["type"] = type;
    if (name != '') data["name"] = name;
    if (userData.keys.isNotEmpty) data["userData"] = userData;

    if (parameters != null) {
      for (String key in parameters!.keys) {
        if (parameters![key] != null) data[key] = parameters![key];
      }

      return data;
    }

    // for simplicity the code assumes attributes are not shared across geometries, see #15811

    data["data"] = {};
    data["data"]["attributes"] = {};

    final index = this.index;

    if (index != null) {
      // TODO
      data["data"]["index"] = {
        "type": index.array.runtimeType.toString(),
        "array": index.array.sublist(0)
      };
    }

    final attributes = this.attributes;

    for (String key in attributes.keys) {
      final attribute = attributes[key];

      // TODO
      // data["data"]["attributes"][ key ] = attribute.toJson( data["data"] );
      data["data"]["attributes"][key] = attribute.toJson();
    }

    Map<String, List<BufferAttribute>> morphAttributes = {};
    bool hasMorphAttributes = false;

    for (String key in morphAttributes.keys) {
      final attributeArray = this.morphAttributes[key]!;

      List<BufferAttribute> array = [];

      for (int i = 0, il = attributeArray.length; i < il; i++) {
        final attribute = attributeArray[i];

        // TODO
        // final attributeData = attribute.toJson( data["data"] );
        // final attributeData = attribute.toJson();

        array.add(attribute);
      }

      if (array.isNotEmpty) {
        morphAttributes[key] = array;

        hasMorphAttributes = true;
      }
    }

    if (hasMorphAttributes) {
      data["data"].morphAttributes = morphAttributes;
      data["data"].morphTargetsRelative = morphTargetsRelative;
    }

    List<Map<String,dynamic>> groups = this.groups;

    if (groups.isNotEmpty) {
      data["data"]["groups"] = json.decode(json.encode(groups));
    }

    final boundingSphere = this.boundingSphere;

    if (boundingSphere != null) {
      List<double> l = List.filled(3, 0);
      boundingSphere.center.copyIntoArray(l);
      data["data"]["boundingSphere"] = {
        "center": l,
        "radius": boundingSphere.radius
      };
    }

    return data;
  }

  BufferGeometry clone() {
    return BufferGeometry().copy(this);
  }

  BufferGeometry copy(BufferGeometry source) {
    // reset

    // this.index = null;
    // this.attributes = {};
    // this.morphAttributes = {};
    // this.groups = [];
    // this.boundingBox = null;
    // this.boundingSphere = null;

    // used for storing cloned, shared data

    // Map data = {};

    // name

    name = source.name;

    // index

    final index = source.index;

    if (index != null) {
      setIndex(index.clone());
    }

    // attributes

    final attributes = source.attributes;

    for (String name in attributes.keys) {
      final attribute = attributes[name];
      setAttributeFromString(name, attribute.clone());
    }

    // morph attributes

    final morphAttributes = source.morphAttributes;

    for (String name in morphAttributes.keys) {
      List<BufferAttribute> array = [];
      final morphAttribute = morphAttributes[name]!;
      // morphAttribute: array of Float32BufferAttributes

      for (int i = 0, l = morphAttribute.length; i < l; i++) {
        array.add(morphAttribute[i].clone());
      }

      this.morphAttributes[name] = array;
    }

    morphTargetsRelative = source.morphTargetsRelative;

    // groups

    List<Map<String,dynamic>> groups = source.groups;

    for (int i = 0, l = groups.length; i < l; i++) {
      final group = groups[i];
      addGroup(group["start"], group["count"], group["materialIndex"]);
    }

    // bounding box

    final boundingBox = source.boundingBox;

    if (boundingBox != null) {
      this.boundingBox = boundingBox.clone();
    }

    // bounding sphere

    final boundingSphere = source.boundingSphere;

    if (boundingSphere != null) {
      this.boundingSphere = boundingSphere.clone();
    }

    // draw range

    drawRange["start"] = source.drawRange["start"]!;
    drawRange["count"] = source.drawRange["count"]!;

    // user data

    userData = source.userData;

    return this;
  }

  void dispose() {
    print(" BufferGeometry dispose ........... ");

    dispatchEvent(Event(type: "dispose"));
  }
}

class BufferGeometryParameters {
  //late List<Shape> shapes;
  late int curveSegments;
  late Map<String, dynamic> options;
  late int steps;
  late double depth;
  late bool bevelEnabled;
  late double bevelThickness;
  late double bevelSize;
  late double bevelOffset;
  late int bevelSegments;
  //late Curve extrudePath;
  late dynamic uvGenerator;
  late int amount;

  BufferGeometryParameters(Map<String, dynamic> json) {
    //shapes = json["shapes"];
    curveSegments = json["curveSegments"];
    options = json["options"];
    depth = json["depth"];
  }

  Map<String, dynamic> toJson() {
    return {"curveSegments": curveSegments};
  }
}