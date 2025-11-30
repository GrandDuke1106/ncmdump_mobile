import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

// 定义 C 函数签名
typedef ConvertFileC = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> src, ffi.Pointer<Utf8> dst);
// 定义 Dart 函数签名
typedef ConvertFileDart = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> src, ffi.Pointer<Utf8> dst);

class NcmDumpService {
  static const _channel = MethodChannel('com.taurusxin.ncmdump/converter');
  
  static ConvertFileDart? _nativeConvertFunc;

  /// 核心转换方法
  static Future<String?> convertFile(String inputPath, String outputDir) async {
    // === 移动端逻辑 (Android/iOS) ===
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final String? result = await _channel.invokeMethod('convertFile', {
          "inputPath": inputPath,
          "outputDir": outputDir,
        });
        
        if (result == "Success") return null;

        return (result != null && result.isNotEmpty) ? result : null; 
      } on PlatformException catch (e) {
        return e.message ?? "未知错误";
      }
    } 
    
    // === 桌面端逻辑 (Windows/Linux) ===
    else if (Platform.isWindows || Platform.isLinux) {
      try {
        _nativeConvertFunc ??= _loadLibrary();
        
        final inputPtr = inputPath.toNativeUtf8();
        final outputPtr = outputDir.toNativeUtf8();

        final resultPtr = _nativeConvertFunc!(inputPtr, outputPtr);

        calloc.free(inputPtr);
        calloc.free(outputPtr);

        if (resultPtr == ffi.nullptr) {
          return null; // 成功
        } else {
          return resultPtr.toDartString(); 
        }
      } catch (e) {
        return "${Platform.operatingSystem}调用失败: $e";
      }
    }
    
    return "不支持的平台";
  }

  static ConvertFileDart _loadLibrary() {
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('ncmdump.dll')
          .lookup<ffi.NativeFunction<ConvertFileC>>('ConvertFile')
          .asFunction();
    } else if (Platform.isLinux) {
      try {
        // [修改点]：这里原来是用 + 号拼接，现在改为插值字符串 '$.../...'
        final libPath = '${File(Platform.resolvedExecutable).parent.path}/lib/libncmdump.so';
        
        return ffi.DynamicLibrary.open(libPath)
            .lookup<ffi.NativeFunction<ConvertFileC>>('ConvertFile')
            .asFunction();
      } catch (_) {
        // 回退尝试直接加载
        return ffi.DynamicLibrary.open('libncmdump.so')
            .lookup<ffi.NativeFunction<ConvertFileC>>('ConvertFile')
            .asFunction();
      }
    }
    throw UnsupportedError("不支持的桌面平台");
  }
}
