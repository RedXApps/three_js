import 'dart:async';
import 'dart:io';
import 'dart:convert' as convert;
import '../utils/blob.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'loader.dart';
import 'package:three_js_core/three_js_core.dart';
import '../ImageLoader/image_loader.dart';

class TextureLoader extends Loader {
  TextureLoader([super.manager,this.flipY = false]);
  bool flipY;

  Texture? _textureProcess(ImageElement? imageElement, String url){
    final Texture texture = Texture();

    //image = image?.convert(format:Format.uint8,numChannels: 4);
    if(imageElement != null){
      // ImageElement imageElement = ImageElement(
      //   url: url,
      //   data: Uint8Array.from(image.getBytes()),
      //   width: image.width,
      //   height: image.height
      // );
      texture.image = imageElement;
      texture.needsUpdate = true;

      return texture;
    }

    return null;
  }
  @override
  Future<Texture?> fromNetwork(Uri uri) async{
    final url = uri.path;
    final ImageElement? image = await ImageLoader(manager,flipY).fromNetwork(uri);
    return _textureProcess(image,url);
  }
  @override
  Future<Texture?> fromFile(File file) async{
    Uint8List bytes = await file.readAsBytes();
    final String url = String.fromCharCodes(bytes).toString().substring(0,50);
    final ImageElement? image = await ImageLoader(manager,flipY).fromBytes(bytes);
    return _textureProcess(image,url);
  }
  @override
  Future<Texture?> fromPath(String filePath) async{
    final ImageElement? image = await ImageLoader(manager,flipY).fromPath(filePath);
    return _textureProcess(image,filePath);
  }
  @override
  Future<Texture?> fromBlob(Blob blob) async{
    final String url = String.fromCharCodes(blob.data).toString().substring(0,50);
    final ImageElement? image = await ImageLoader(manager,flipY).fromBlob(blob);
    return _textureProcess(image,url);
  }
  @override
  Future<Texture?> fromAsset(String asset, {String? package}) async{
    final ImageElement? image = await ImageLoader(manager,flipY).fromAsset(asset, package: package);
    return _textureProcess(image,'$package/$asset');
  }
  @override
  Future<Texture?> fromBytes(Uint8List bytes) async{
    final String url = String.fromCharCodes(bytes).toString().substring(0,50);
    final ImageElement? image = await ImageLoader(manager,flipY).fromBytes(bytes);
    return _textureProcess(image,url);
  }

  Future<Texture?> unknown(dynamic url) async{
    if(url is File){
      return fromFile(url);
    }
    else if(url is Blob){
      return fromBlob(url);
    }
    else if(url is Uri){
      return fromNetwork(url);
    }
    else if(url is Uint8List){
      return fromBytes(url);
    }
    else if(url is String){
      RegExp dataUriRegex = RegExp(r"^data:(.*?)(;base64)?,(.*)$");
      if(dataUriRegex.hasMatch(url)){
        RegExpMatch? dataUriRegexResult = dataUriRegex.firstMatch(url);
        String? data = dataUriRegexResult!.group(3)!;

        return fromBytes(convert.base64.decode(data));
      }
      else if(url.contains('http://') || url.contains('https://')){  
        return fromNetwork(Uri.parse(url));
      }
      else if(url.contains('assets')){
        return fromAsset(url);
      }
      else{
        return fromPath(url);
      }
    }

    return null;
  }

  @override
  TextureLoader setPath(String path){
    super.setPath(path);
    return this;
  }
  @override
  TextureLoader setCrossOrigin(String crossOrigin) {
    super.setCrossOrigin(crossOrigin);
    return this;
  }
  @override
  TextureLoader setWithCredentials(bool value) {
    super.setWithCredentials(value);
    return this;
  }
  @override
  TextureLoader setResourcePath(String? resourcePath) {
    super.setResourcePath(resourcePath);
    return this;
  }
  @override
  TextureLoader setRequestHeader(Map<String, dynamic> requestHeader) {
    super.setRequestHeader(requestHeader);
    return this;
  }
}