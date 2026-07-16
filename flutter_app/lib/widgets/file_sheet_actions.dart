import 'package:flutter/material.dart';
import '../models/file_item.dart';

/// A single action row inside a modal bottom sheet.
///
/// Usage: each row closes the sheet then fires [action].
class SheetAction extends StatelessWidget {
  final BuildContext sheetContext;
  final IconData icon;
  final String title;
  final VoidCallback action;

  const SheetAction({
    super.key,
    required this.sheetContext,
    required this.icon,
    required this.title,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(sheetContext);
        action();
      },
    );
  }
}

/// The action list inside the file bottom sheet (open / download / upload / …).
class FileSheetActions extends StatelessWidget {
  final BuildContext sheetContext;
  final FileItem file;

  /// translators
  final String Function(String) tr;

  /// file.isDir ? enterDir() : null
  final VoidCallback? onOpen;

  /// !file.isDir ? download() : null
  final VoidCallback? onDownload;

  /// file.isDir ? downloadAsZip() : null
  final VoidCallback? onDownloadAsZip;

  /// file.isDir ? downloadToFolder() : null
  final VoidCallback? onDownloadToFolder;

  /// file.isDir ? upload(targetDir: file.path) : null
  final VoidCallback? onUploadToDir;

  /// copy path to clipboard
  final VoidCallback? onCopyPath;

  /// rename dialog
  final VoidCallback? onRename;

  /// delete confirmation
  final VoidCallback? onDelete;

  /// file.isDir ? createFileOrFolder(directory: false, targetDir: file.path) : null
  final VoidCallback? onNewFile;

  /// file.isDir ? createFileOrFolder(directory: true, targetDir: file.path) : null
  final VoidCallback? onNewFolder;

  /// show file info dialog
  final VoidCallback? onDetails;

  const FileSheetActions({
    super.key,
    required this.sheetContext,
    required this.file,
    required this.tr,
    this.onOpen,
    this.onDownload,
    this.onDownloadAsZip,
    this.onDownloadToFolder,
    this.onUploadToDir,
    this.onCopyPath,
    this.onRename,
    this.onDelete,
    this.onNewFile,
    this.onNewFolder,
    this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (file.isDir && onOpen != null)
          SheetAction(
            sheetContext: sheetContext,
            icon: Icons.folder_open,
            title: tr('open'),
            action: onOpen!,
          ),
        if (!file.isDir && onDownload != null)
          SheetAction(
            sheetContext: sheetContext,
            icon: Icons.download,
            title: tr('downloadTooltip'),
            action: onDownload!,
          ),
        if (file.isDir && onDownloadAsZip != null)
          SheetAction(
            sheetContext: sheetContext,
            icon: Icons.folder_zip,
            title: tr('downloadAsZip'),
            action: onDownloadAsZip!,
          ),
        if (file.isDir && onDownloadToFolder != null)
          SheetAction(
            sheetContext: sheetContext,
            icon: Icons.folder,
            title: tr('downloadToFolder'),
            action: onDownloadToFolder!,
          ),
        if (file.isDir && onUploadToDir != null)
          SheetAction(
            sheetContext: sheetContext,
            icon: Icons.upload,
            title: tr('uploadToDir'),
            action: onUploadToDir!,
          ),
        if (onCopyPath != null)
          SheetAction(
            sheetContext: sheetContext,
            icon: Icons.copy,
            title: tr('copyPath'),
            action: onCopyPath!,
          ),
        if (onRename != null)
          SheetAction(
            sheetContext: sheetContext,
            icon: Icons.drive_file_rename_outline,
            title: tr('rename'),
            action: onRename!,
          ),
        if (onDelete != null)
          SheetAction(
            sheetContext: sheetContext,
            icon: Icons.delete_outline,
            title: tr('delete'),
            action: onDelete!,
          ),
        if (file.isDir && onNewFile != null) ...[
          const Divider(),
          SheetAction(
            sheetContext: sheetContext,
            icon: Icons.note_add_outlined,
            title: tr('newFile'),
            action: onNewFile!,
          ),
          SheetAction(
            sheetContext: sheetContext,
            icon: Icons.create_new_folder_outlined,
            title: tr('newFolder'),
            action: onNewFolder!,
          ),
        ],
        const Divider(),
        if (onDetails != null)
          SheetAction(
            sheetContext: sheetContext,
            icon: Icons.info_outline,
            title: tr('details'),
            action: onDetails!,
          ),
      ],
    );
  }
}
