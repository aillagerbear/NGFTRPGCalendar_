import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;
import 'loading_screen.dart';

// Conditional import
import 'package:calendartrpg/utils/image_picker_web.dart'
if (dart.library.io) 'package:calendartrpg/utils/image_picker_mobile.dart' as image_picker;

void log(String message) {
  developer.log(message, name: 'ProfileEditDialog');
}

class ProfileEditDialog extends StatefulWidget {
  final User user;

  ProfileEditDialog({required this.user});

  @override
  _ProfileEditDialogState createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog> {
  late TextEditingController _nameController;
  Uint8List? _imageBytes;
  bool _isImageSelected = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    log('Initializing ProfileEditDialog state');
    _nameController = TextEditingController(text: widget.user.displayName ?? '');
    log('ProfileEditDialog initialized. User: ${widget.user.uid}, DisplayName: ${widget.user.displayName}');
    log('Current user photoURL: ${widget.user.photoURL}');
  }

  @override
  void dispose() {
    log('Disposing ProfileEditDialog');
    _nameController.dispose();
    log('ProfileEditDialog disposed');
    super.dispose();
  }

  Future<void> _pickImage() async {
    log('Picking image');
    Uint8List? pickedImage = await image_picker.pickImage();

    if (pickedImage != null) {
      setState(() {
        _imageBytes = pickedImage;
        _isImageSelected = true;
      });
      log('Image picked successfully');
    } else {
      log('No image selected');
    }
  }

  Widget _buildImageWidget() {
    log('Building image widget');
    if (_isImageSelected && _imageBytes != null) {
      log('Displaying selected image');
      return Image.memory(_imageBytes!, height: 100);
    } else if (widget.user.photoURL != null) {
      log('Displaying existing user photo: ${widget.user.photoURL}');
      return Image.network(
        widget.user.photoURL!,
        height: 100,
        errorBuilder: (context, error, stackTrace) {
          log('Error loading image: $error');
          log('Error stack trace: $stackTrace');
          return Icon(Icons.error);
        },
        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
          );
        },
      );
    } else {
      log('Displaying default icon');
      return Icon(Icons.person, size: 100);
    }
  }

  @override
  Widget build(BuildContext context) {
    log('Building ProfileEditDialog widget');
    final authService = Provider.of<AuthService>(context);

    return AlertDialog(
      title: Text('프로필 수정'),
      content: _isLoading
          ? LoadingScreen()
          : SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: '이름'),
            ),
            SizedBox(height: 20),
            _buildImageWidget(),
            ElevatedButton(
              child: Text('프로필 사진 변경'),
              onPressed: _pickImage,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('취소'),
          onPressed: () {
            log('Profile edit cancelled');
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: Text('저장'),
          onPressed: _isLoading ? null : () => _saveProfile(authService),
        ),
      ],
    );
  }

  Future<void> _saveProfile(AuthService authService) async {
    setState(() => _isLoading = true);
    log('Profile save initiated');
    try {
      log('Updating user name: ${_nameController.text}');
      await authService.updateUserName(_nameController.text);
      log('User name updated successfully');

      if (_isImageSelected && _imageBytes != null) {
        log('Updating user photo. Image size: ${_imageBytes!.length} bytes');
        if (kIsWeb) {
          log('Updating user photo for web');
          await authService.updateUserPhotoWeb(_imageBytes!);
        } else {
          log('Updating user photo for mobile');
          final tempDir = await getTemporaryDirectory();
          File file = await File('${tempDir.path}/image.png').create();
          file.writeAsBytesSync(_imageBytes!);
          log('Temporary file created: ${file.path}');
          await authService.updateUserPhoto(file);
        }
        log('User photo update request sent');
      } else {
        log('No new image selected, skipping photo update');
      }

      log('Profile update completed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프로필이 업데이트되었습니다')),
      );
      Navigator.of(context).pop();
    } catch (e, stackTrace) {
      log('Profile update failed: $e');
      log('Error stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프로필 업데이트 중 오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}