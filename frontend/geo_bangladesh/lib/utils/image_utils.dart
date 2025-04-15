import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';

class ImageUtils {
  // Resize and compress image to 800x600 (Mobile only)
  static Future<File> resizeAndCompressImage(File imageFile) async {
    if (kIsWeb) {
      throw Exception('resizeAndCompressImage with File is not supported on web. Use processXFile instead.');
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(tempDir.path, 'compressed_${path.basename(imageFile.path)}');

      // Compress the image
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 85, // Quality of the compressed image
        minWidth: 800, // Target width
        minHeight: 600, // Target height
      );

      if (result == null) {
        throw Exception('Image compression failed');
      }

      return File(result.path);
    } catch (e) {
      print('Error in resizeAndCompressImage: $e');
      // If compression fails, return the original file
      return imageFile;
    }
  }

  // Process XFile for cross-platform compatibility
  static Future<XFile> processXFile(XFile xFile) async {
    try {
      if (kIsWeb) {
        // On web, we can't do much processing due to browser limitations
        // Just return the original XFile
        return xFile;
      } else {
        // On mobile, we can process the file
        final File file = File(xFile.path);
        final File compressedFile = await resizeAndCompressImage(file);
        return XFile(compressedFile.path);
      }
    } catch (e) {
      print('Error processing XFile: $e');
      // Return the original on error
      return xFile;
    }
  }

  // Get bytes from XFile for web preview
  static Future<Uint8List?> getXFileBytes(XFile xFile) async {
    try {
      return await xFile.readAsBytes();
    } catch (e) {
      print('Error reading XFile bytes: $e');
      return null;
    }
  }
}