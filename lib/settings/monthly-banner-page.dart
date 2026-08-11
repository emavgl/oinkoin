import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:piggybank/helpers/banner-image-service.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/settings/style.dart';

/// Shows a temporary dialog with a full-size preview of a banner image.
void showBannerImagePreview(BuildContext context, String token,
    {String? title}) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(title, style: titleTextStyle),
            ),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400, minHeight: 200),
              child: Image(
                image: BannerImageService.resolveToken(token),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    Image.asset(BannerImageService.defaultAsset),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("OK".i18n),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Lets the user pick a banner picture for each of the 12 months. Tapping a
/// month opens a picker where they can also upload their own pictures;
/// long-pressing any image shows a temporary preview.
class MonthlyBannerPage extends StatefulWidget {
  const MonthlyBannerPage({super.key});

  @override
  State<MonthlyBannerPage> createState() => _MonthlyBannerPageState();
}

class _MonthlyBannerPageState extends State<MonthlyBannerPage> {
  late Map<int, String> _assignments;

  @override
  void initState() {
    super.initState();
    _assignments = BannerImageService.loadAssignmentsSync();
  }

  Future<void> _assignForMonth(int month) async {
    final token = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ImagePickerSheet(month: month),
    );
    if (token == null || token.isEmpty) return;
    setState(() {
      if (token ==
          BannerImageService.assetToken(
              BannerImageService.monthAssetName(month))) {
        // Selecting the month's own built-in image is the default; keep the
        // stored assignments empty for it.
        _assignments.remove(month);
      } else {
        _assignments[month] = token;
      }
    });
    await BannerImageService.saveAssignments(_assignments);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Monthly banner".i18n)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Tap a month to choose its banner image. Long-press to preview."
                .i18n,
            style: subtitleTextStyle,
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.8,
            children: List.generate(12, (index) {
              final month = index + 1;
              return _buildMonthTile(month);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthTile(int month) {
    final token = _assignments[month] ??
        BannerImageService.assetToken(BannerImageService.monthAssetName(month));
    final isCustom = token.startsWith(BannerImageService.userPrefix);

    return GestureDetector(
      onTap: () => _assignForMonth(month),
      onLongPress: () => showBannerImagePreview(
        context,
        token,
        title: extractMonthString(DateTime(2000, month)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: BannerImageService.resolveToken(token),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                        BannerImageService.defaultAsset,
                        fit: BoxFit.cover),
                  ),
                  if (isCustom)
                    const Positioned(
                      right: 4,
                      top: 4,
                      child: Icon(Icons.photo, size: 16, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            extractMonthString(DateTime(2000, month)),
            textAlign: TextAlign.center,
            style: subtitleTextStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet used to pick the banner image for one month. The "Add image"
/// tile comes first so importing a new picture is always visible; uploading a
/// picture automatically applies it to the month and closes the sheet.
class _ImagePickerSheet extends StatefulWidget {
  final int month;

  const _ImagePickerSheet({required this.month});

  @override
  State<_ImagePickerSheet> createState() => _ImagePickerSheetState();
}

class _ImagePickerSheetState extends State<_ImagePickerSheet> {
  late List<UploadedBannerImage> _uploads;

  @override
  void initState() {
    super.initState();
    _uploads = BannerImageService.loadUploadsSync();
  }

  Future<void> _addImage() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(type: FileType.image);
    } catch (_) {
      result = null;
    }
    if (result == null || result.files.single.path == null) return;
    final upload =
        await BannerImageService.importImage(result.files.single.path!);
    if (upload == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Could not add the image".i18n),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final uploads = BannerImageService.loadUploadsSync()..add(upload);
    await BannerImageService.saveUploads(uploads);
    // The uploaded picture is automatically applied to the selected month
    // and the sheet closes.
    Navigator.of(context).pop(upload.token);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select a picture for %s"
                  .i18n
                  .fill([extractMonthString(DateTime(2000, widget.month))]),
              style: titleTextStyle,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
                children: [
                  _buildAddChoiceTile(),
                  ...List.generate(12, (index) {
                    final month = index + 1;
                    final token = BannerImageService.assetToken(
                        BannerImageService.monthAssetName(month));
                    return _buildChoiceTile(
                      token,
                      label: extractMonthString(DateTime(2000, month)),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceTile(
    String token, {
    required String label,
  }) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(token),
      onLongPress: () => showBannerImagePreview(context, token, title: label),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image(
                image: BannerImageService.resolveToken(token),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                    BannerImageService.defaultAsset,
                    fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: subtitleTextStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAddChoiceTile() {
    final last = _uploads.isEmpty ? null : _uploads.last;
    return GestureDetector(
      onTap: _addImage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: last == null
                  ? Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey, width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.add_a_photo_outlined, size: 28),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image(
                          image: BannerImageService.resolveToken(last.token),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(BannerImageService.defaultAsset,
                                  fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(3),
                            child: const Icon(Icons.add,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Add image".i18n,
            textAlign: TextAlign.center,
            style: subtitleTextStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
