import 'package:image_picker/image_picker.dart';

/// Boundary around the current native camera hand-off. A CameraController
/// implementation can replace it later without changing import persistence.
abstract interface class GarmentCapture {
  Future<String?> capture();
}

class ImagePickerGarmentCapture implements GarmentCapture {
  final ImagePicker picker;
  ImagePickerGarmentCapture({ImagePicker? picker}) : picker = picker ?? ImagePicker();

  @override
  Future<String?> capture() async => (await picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 90,
    maxWidth: 1800,
  ))?.path;
}
