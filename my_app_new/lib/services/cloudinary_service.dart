import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = "fj653k18";
  static const String uploadPreset = "avatar_upload";

  Future<String?> upload(Uint8List bytes) async {
    final uri = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
    );

    final request = http.MultipartRequest("POST", uri);

    request.fields["upload_preset"] = uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes(
        "file",
        bytes,
        filename: "avatar.jpg",
      ),
    );

    final response = await request.send();

    if (response.statusCode != 200) {
      final error = await response.stream.bytesToString();
      throw Exception(error);
    }

    final data = jsonDecode(
      await response.stream.bytesToString(),
    );

    return data["secure_url"] as String;
  }
}