import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_js_math/three_js_math.dart';
import 'package:three_js_core/three_js_core.dart';

final _box = BoundingBox();

class BoxHelper extends LineSegments {
  Object3D? object;

  BoxHelper.create(super.geometry, super.material);

  factory BoxHelper(object, {color = 0xffff00}) {
    final indices = Uint16Array.from([
      0,
      1,
      1,
      2,
      2,
      3,
      3,
      0,
      4,
      5,
      5,
      6,
      6,
      7,
      7,
      4,
      0,
      4,
      1,
      5,
      2,
      6,
      3,
      7
    ]);
    final positions = Float32Array(8 * 3);

    final geometry = BufferGeometry();
    geometry.setIndex(Uint16BufferAttribute(indices, 1, false));
    geometry.setAttributeFromString('position', Float32BufferAttribute(positions, 3, false));

    final boxHelper = BoxHelper.create(
        geometry, LineBasicMaterial.fromMap({"color": color, "toneMapped": false}));

    boxHelper.object = object;
    boxHelper.type = 'BoxHelper';

    boxHelper.matrixAutoUpdate = false;

    boxHelper.update();

    return boxHelper;
  }

  void update() {
    if (object != null) {
      _box.setFromObject(object!);
    }

    if (_box.isEmpty()) return;

    final min = _box.min;
    final max = _box.max;

    /*
			5____4
		1/___0/|
		| 6__|_7
		2/___3/

		0: max.x, max.y, max.z
		1: min.x, max.y, max.z
		2: min.x, min.y, max.z
		3: max.x, min.y, max.z
		4: max.x, max.y, min.z
		5: min.x, max.y, min.z
		6: min.x, min.y, min.z
		7: max.x, min.y, min.z
		*/

    final position = geometry!.attributes["position"];
    final array = position.array;

    array[0] = max.x;
    array[1] = max.y;
    array[2] = max.z;
    array[3] = min.x;
    array[4] = max.y;
    array[5] = max.z;
    array[6] = min.x;
    array[7] = min.y;
    array[8] = max.z;
    array[9] = max.x;
    array[10] = min.y;
    array[11] = max.z;
    array[12] = max.x;
    array[13] = max.y;
    array[14] = min.z;
    array[15] = min.x;
    array[16] = max.y;
    array[17] = min.z;
    array[18] = min.x;
    array[19] = min.y;
    array[20] = min.z;
    array[21] = max.x;
    array[22] = min.y;
    array[23] = min.z;

    position.needsUpdate = true;

    geometry!.computeBoundingSphere();
  }

  BoxHelper setFromObject(object) {
    this.object = object;
    update();

    return this;
  }

  // copy( BoxHelper source ) {

  // 	LineSegments.prototype.copy.call( this, source );

  // 	this.object = source.object;

  // 	return this;

  // }

}