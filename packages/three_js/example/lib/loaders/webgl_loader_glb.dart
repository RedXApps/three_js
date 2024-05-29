import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;

class WebglLoaderGlb extends StatefulWidget {
  final String fileName;
  const WebglLoaderGlb({super.key, required this.fileName});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<WebglLoaderGlb> {
  late three.ThreeJS threeJs;

  @override
  void initState() {
    threeJs = three.ThreeJS(
      
      onSetupComplete: (){setState(() {});},
      setup: setup,
      // postProcessor: ([dt]){
      //   threeJs.renderer!.clear(true, true, true);
      // },
      settings: three.Settings(
        clearAlpha: 0,
        clearColor: 0xffffff
      ),
    );
    super.initState();
  }
  @override
  void dispose() {
    threeJs.dispose();
    controls.clearListeners();
    three.loading.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
      ),
      body: threeJs.build()
    );
  }

  late three.OrbitControls controls;
  
  Future<void> setup() async {
    threeJs.camera = three.PerspectiveCamera(45, threeJs.width / threeJs.height, 1, 2200);
    threeJs.camera.position.setValues(3, 6, 10);
    controls = three.OrbitControls(threeJs.camera, threeJs.globalKey);
    threeJs.scene = three.Scene();

    final ambientLight = three.AmbientLight(0xffffff, 0.9);
    threeJs.scene.add(ambientLight);

    final pointLight = three.PointLight(0xffffff, 0.8);

    pointLight.position.setValues(0, 0, 0);

    threeJs.camera.add(pointLight);
    threeJs.scene.add(threeJs.camera);

    threeJs.camera.lookAt(threeJs.scene.position);

    three.GLTFLoader loader = three.GLTFLoader().setPath('assets/models/gltf/');

    //final result = await loader.fromAsset( 'coffeemat.glb' );
    var result = await loader.fromAsset( 'BoomBox.glb' );
    // var result = await loader.loadAsync('untitled.glb');

    final object = result!.scene;

    print(object);

    object.scale.setValues(80, 80, 80);
    object.rotation.set(0, 180 * math.pi / 180.0, 0);

    threeJs.scene.add(object);

    threeJs.addAnimationEvent((dt){
      controls.update();
    });
  }
}
