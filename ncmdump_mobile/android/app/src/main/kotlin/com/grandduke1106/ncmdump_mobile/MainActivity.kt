package com.grandduke1106.ncmdump_mobile

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import bridge.Bridge
import kotlinx.coroutines.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.taurusxin.ncmdump/converter"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "convertFile") {
                val inputPath = call.argument<String>("inputPath")
                val outputDir = call.argument<String>("outputDir")

                if (inputPath != null) {
                    // 使用协程在后台线程运行，避免阻塞 UI
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            // 调用 Go 的函数
                            val errorMsg = Bridge.convertFile(inputPath, outputDir ?: "")
                            withContext(Dispatchers.Main) {
                                if (errorMsg.isEmpty()) {
                                    result.success("Success")
                                } else {
                                    result.error("CONVERT_ERR", errorMsg, null)
                                }
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("NATIVE_ERR", e.message, null)
                            }
                        }
                    }
                } else {
                    result.error("INVALID_ARGS", "Input path is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
