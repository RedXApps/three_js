import 'package:flutter_gl/flutter_gl.dart';
import '../core/index.dart';
import '../materials/index.dart';
import 'package:three_js_math/three_js_math.dart';
import 'dart:math' as math;

final _start = Vector3.zero();
final _end = Vector3.zero();
final _inverseMatrix = Matrix4.identity();
final _ray = Ray();
final _sphere = BoundingSphere();

class Line extends Object3D {
  Line(BufferGeometry? geometry, Material? material) : super() {
    this.geometry = geometry ?? BufferGeometry();
    this.material = material ?? LineBasicMaterial(<MaterialProperty, dynamic>{});
    type = "Line";
    updateMorphTargets();
  }

  Line.fromJson(Map<String, dynamic> json, Map<String, dynamic> rootJson):super.fromJson(json, rootJson) {
    type = "Line";
  }

  @override
  Line copy(Object3D source, [bool? recursive]) {
    super.copy(source);

    material = source.material;
    geometry = source.geometry;

    return this;
  }

  @override
  Line clone([bool? recursive = true]) {
    return Line(geometry!, material!).copy(this, recursive);
  }

  Line computeLineDistances() {
    final geometry = this.geometry;

    if (geometry is BufferGeometry) {
      // we assume non-indexed geometry

      if (geometry.index == null) {
        final positionAttribute = geometry.attributes["position"];

        // List<num> lineDistances = [ 0.0 ];
        final lineDistances = Float32Array(positionAttribute.count + 1);

        lineDistances[0] = 0.0;

        for (int i = 1, l = positionAttribute.count; i < l; i++) {
          _start.fromBuffer(positionAttribute, i - 1);
          _end.fromBuffer(positionAttribute, i);

          lineDistances[i] = lineDistances[i - 1];
          lineDistances[i] += _start.distanceTo(_end);
        }

        geometry.setAttributeFromString('lineDistance', Float32BufferAttribute(lineDistances, 1, false));
      }
      // else {
      //   print(
      //       'THREE.Line.computeLineDistances(): Computation only possible with non-indexed BufferGeometry.');
      // }
    }
    // else if (geometry.isGeometry) {
    //   throw ('THREE.Line.computeLineDistances() no longer supports THREE.Geometry. Use THREE.BufferGeometry instead.');
    // }

    return this;
  }

  @override
  void raycast(Raycaster raycaster, List<Intersection> intersects) {
    final geometry = this.geometry!;
    final matrixWorld = this.matrixWorld;
    final threshold = raycaster.params["Line"]["threshold"];
    final drawRange = geometry.drawRange;

    // Checking boundingSphere distance to ray

    if (geometry.boundingSphere == null) geometry.computeBoundingSphere();

    _sphere.setFrom(geometry.boundingSphere!);
    _sphere.applyMatrix4(matrixWorld);
    _sphere.radius += threshold;

    if (raycaster.ray.intersectsSphere(_sphere) == false) return;

    //

    _inverseMatrix..setFrom(matrixWorld)..invert();
    _ray..copyFrom(raycaster.ray)..applyMatrix4(_inverseMatrix);

    final localThreshold = threshold / ((scale.x + scale.y + scale.z) / 3);
    final localThresholdSq = localThreshold * localThreshold;

    final vStart = Vector3.zero();
    final vEnd = Vector3.zero();
    final interSegment = Vector3.zero();
    final interRay = Vector3.zero();
    final step = type == "LineSegments" ? 2 : 1;

    final index = geometry.index;
    final attributes = geometry.attributes;
    final positionAttribute = attributes["position"];

    if (index != null) {
      final start = math.max<int>(0, drawRange["start"]!);
      final end = math.min<int>(
        index.count,
        (drawRange["start"]! + drawRange["count"]!),
      );

      for (int i = start, l = end - 1; i < l; i += step) {
        final a = index.getX(i)!;
        final b = index.getX(i + 1)!;

        vStart.fromBuffer(positionAttribute, a.toInt());
        vEnd.fromBuffer(positionAttribute, b.toInt());

        final distSq =
            _ray.distanceSqToSegment(vStart, vEnd, interRay, interSegment);

        if (distSq > localThresholdSq) continue;

        interRay.applyMatrix4(this.matrixWorld); //Move back to world space for distance calculation

        final distance = raycaster.ray.origin.distanceTo(interRay);

        if (distance < raycaster.near || distance > raycaster.far) continue;

        intersects.add(Intersection(
          distance: distance,
          // What do we want? intersection point on the ray or on the segment??
          // point: raycaster.ray.at( distance ),
          point: interSegment.clone()..applyMatrix4(this.matrixWorld),
          index: i,
          object: this
        ));
      }
    } else {
      final start = math.max<int>(0, drawRange["start"]!);
      final end = math.min<int>(
        positionAttribute.count,
        (drawRange["start"]! + drawRange["count"]!),
      );

      for (int i = start, l = end - 1; i < l; i += step) {
        vStart.fromBuffer(positionAttribute, i);
        vEnd.fromBuffer(positionAttribute, i + 1);

        final distSq =
            _ray.distanceSqToSegment(vStart, vEnd, interRay, interSegment);

        if (distSq > localThresholdSq) continue;

        interRay.applyMatrix4(this
            .matrixWorld); //Move back to world space for distance calculation

        final distance = raycaster.ray.origin.distanceTo(interRay);

        if (distance < raycaster.near || distance > raycaster.far) continue;

        intersects.add(Intersection(
          distance: distance,
          // What do we want? intersection point on the ray or on the segment??
          // point: raycaster.ray.at( distance ),
          point: interSegment.clone()..applyMatrix4(this.matrixWorld),
          index: i,
          object: this
        ));
      }
    }
  }

  void updateMorphTargets() {
    final geometry = this.geometry!;

    final morphAttributes = geometry.morphAttributes;
    final keys = morphAttributes.keys.toList();

    if (keys.isNotEmpty) {
      final morphAttribute = morphAttributes[keys[0]];

      if (morphAttribute != null) {
        morphTargetInfluences = [];
        morphTargetDictionary = {};

        for (int m = 0, ml = morphAttribute.length; m < ml; m++) {
          final name = morphAttribute[m].name ?? m.toString();

          morphTargetInfluences!.add(0);
          morphTargetDictionary![name] = m;
        }
      }
    }

    // else {
    //   final morphTargets = geometry.morphTargets;

    //   if (morphTargets != null && morphTargets.length > 0) {
    //     print(
    //         'THREE.Line.updateMorphTargets() does not support THREE.Geometry. Use THREE.BufferGeometry instead.');
    //   }
    // }
  }
}