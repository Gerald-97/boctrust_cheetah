package com.boctrust.boctrust_savings_loan

import android.net.Uri
import android.os.Handler
import android.os.Looper
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private val scanExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "boctrust/scan_text")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognizeImage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("invalid_argument", "A path is required.", null)
                    return@setMethodCallHandler
                }
                scanExecutor.execute {
                    try {
                        val lines = recognizeLines(path)
                        mainHandler.post { result.success(lines) }
                    } catch (e: Throwable) {
                        // Includes OutOfMemoryError from the full-resolution decode, so
                        // Dart always gets a reply. The message may name the file; send
                        // only its type.
                        mainHandler.post {
                            result.error("recognition_failed", e.javaClass.simpleName, null)
                        }
                    }
                }
            }
    }

    override fun onDestroy() {
        scanExecutor.shutdown()
        super.onDestroy()
    }

    // Runs on the scan executor. fromFilePath decodes at full resolution and
    // applies EXIF rotation, so the image and its width/height are upright.
    private fun recognizeLines(path: String): List<Map<String, Any>> {
        val image = InputImage.fromFilePath(applicationContext, Uri.fromFile(File(path)))
        val width = image.width.toDouble()
        val height = image.height.toDouble()
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        try {
            val text = Tasks.await(recognizer.process(image))
            val lines = mutableListOf<Map<String, Any>>()
            for (block in text.textBlocks) {
                for (line in block.lines) {
                    val box = line.boundingBox ?: continue
                    // Boxes can overhang the image by a few pixels; keep the visible part.
                    val left = box.left.coerceIn(0, image.width)
                    val top = box.top.coerceIn(0, image.height)
                    val right = box.right.coerceIn(left, image.width)
                    val bottom = box.bottom.coerceIn(top, image.height)
                    lines.add(
                        mapOf(
                            "text" to line.text,
                            "left" to left / width,
                            "top" to top / height,
                            "width" to (right - left) / width,
                            "height" to (bottom - top) / height,
                        ),
                    )
                }
            }
            return lines
        } finally {
            recognizer.close()
        }
    }
}
