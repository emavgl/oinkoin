import 'dart:developer';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:future_progress_dialog/future_progress_dialog.dart';
import 'package:i18n_extension/default.i18n.dart';

import '../helpers/alert-dialog-builder.dart';
import '../services/backup-service.dart';

class BackupRestoreDialog {

  static Future<String?> showRestoreBackupDialog(BuildContext context) {
    TextEditingController passwordController = TextEditingController();
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter decryption password'.i18n),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("It appears the file has been encrypted. Enter the password:".i18n),
              SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password'.i18n,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog without action
              },
              child: Text("Cancel".i18n),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(passwordController.text); // Return password if provided
              },
              child: Text("Load".i18n),
            ),
          ],
        );
      },
    );
  }

  static Future<void> importFromBackupFile(BuildContext context) async {
    var hasDeletedCache = await FilePicker.platform.clearTemporaryFiles();
    log("FilePicker has deleted cache: " + hasDeletedCache.toString());
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null) {
      File file = File(result.files.single.path!);
      String? password;
      if (await BackupService.isEncrypted(file)) {
        password = await showRestoreBackupDialog(context);
        if (password != null && password.isNotEmpty) {
          password = BackupService.hashPassword(password);
        } else {
          await showBackupRestoreDialog(context,
              "Restore unsuccessful".i18n,
              "Can't decrypt without a password".i18n
          );
          return;
        }
      }
      bool successful = await showDialog(
        context: context,
        builder: (context) =>
            FutureProgressDialog(
                BackupService.importDataFromBackupFile(file,
                    encryptionPassword: password)
            ),
      );
      if (successful) {
        await showBackupRestoreDialog(context,
            "Restore successful".i18n,
            "The data from the backup file are now restored.".i18n
        );
      } else {
        await showBackupRestoreDialog(context,
            "Restore unsuccessful".i18n,
            "Make sure you have the latest version of the app. If so, the backup file may be corrupted.".i18n
        );
      }
    } else {
      // User has canceled the picker
      log("User canceled file picking");
    }
  }

  static Future<void> showBackupRestoreDialog(BuildContext context, String title, String subtitle) async {
    AlertDialogBuilder resultDialog = AlertDialogBuilder(title)
        .addSubtitle(subtitle)
        .addTrueButtonName("OK");
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return resultDialog.build(context);
        });
  }
}