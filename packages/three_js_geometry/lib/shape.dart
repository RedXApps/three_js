import 'dart:typed_data';
import 'package:three_js_core/core/index.dart';
import 'package:three_js_math/three_js_math.dart';
import 'package:three_js_curves/three_js_curves.dart';

class ShapeGeometry extends BufferGeometry {
  late List<Shape> shapes;

  ShapeGeometry(this.shapes, {int curveSegments = 12}) : super() {
    type = 'ShapeGeometry';
    parameters = {};
    this.curveSegments = curveSegments;
    init();
  }

  void init() {
    parameters!["shapes"] = shapes;
    parameters!["curveSegments"] = curveSegments;

    // buffers

    final indices = [];
    List<double> vertices = [];
    List<double> normals = [];
    List<double> uvs = [];

    // helper variables

    int groupStart = 0;
    int groupCount = 0;

    // allow single and array values for "shapes" parameter

    addShape(shape) {
      final indexOffset = vertices.length / 3;
      final points = shape.extractPoints(curveSegments);

      List<Vector?> shapeVertices = points["shape"];
      List<List<Vector?>> shapeHoles = (points["holes"] as List).map((item) => item as List<Vector?>).toList();

      // check direction of vertices

      if (ShapeUtils.isClockWise(shapeVertices) == false) {
        shapeVertices = shapeVertices.reversed.toList();
      }

      for (int i = 0, l = shapeHoles.length; i < l; i++) {
        final shapeHole = shapeHoles[i];

        if (ShapeUtils.isClockWise(shapeHole) == true) {
          shapeHoles[i] = shapeHole.reversed.toList();
        }
      }

      final faces = ShapeUtils.triangulateShape(shapeVertices, shapeHoles);

      // join vertices of inner and outer paths to a single array

      for (int i = 0, l = shapeHoles.length; i < l; i++) {
        final shapeHole = shapeHoles[i];
        shapeVertices.addAll(shapeHole);
      }

      // vertices, normals, uvs

      for (int i = 0, l = shapeVertices.length; i < l; i++) {
        final vertex = shapeVertices[i];
        if(vertex != null){
          vertices.addAll([vertex.x.toDouble(), vertex.y.toDouble(), 0.0]);
          normals.addAll([0.0, 0.0, 1.0]);
          uvs.addAll([vertex.x.toDouble(), vertex.y.toDouble()]); // world uvs
        }

      }

      // incides

      for (int i = 0, l = faces.length; i < l; i++) {
        final face = faces[i];

        final a = face[0] + indexOffset;
        final b = face[1] + indexOffset;
        final c = face[2] + indexOffset;

        indices.addAll([a.toInt(), b.toInt(), c.toInt()]);
        groupCount += 3;
      }
    }


    for (int i = 0; i < shapes.length; i++) {
      addShape(shapes[i]);
      addGroup(groupStart, groupCount, i); // enables MultiMaterial support
      groupStart += groupCount;
      groupCount = 0;
    }

    setIndex(indices);
    setAttribute(Semantic.position,Float32BufferAttribute.fromTypedData(Float32List.fromList(vertices), 3, false));
    setAttribute(Semantic.normal, Float32BufferAttribute.fromTypedData(Float32List.fromList(normals), 3, false));
    setAttribute(Semantic.uv, Float32BufferAttribute.fromTypedData(Float32List.fromList(uvs), 2, false));
  }
}