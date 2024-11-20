import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class FilePickerWidget extends StatefulWidget {
  const FilePickerWidget({super.key, required this.onFileChosen});

  final Function(String) onFileChosen;

  @override
  State<FilePickerWidget> createState() => _FilePickerWidgetState();
}

class _FilePickerWidgetState extends State<FilePickerWidget> {

  String? _filename;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        FilePickerResult? result = await FilePicker.platform.pickFiles();
        if (result!= null) {
          setState(() {
            _filename = result.files.single.name;
          });
          widget.onFileChosen(result.files.single.path!);
        }
      },
      child: Text(_filename ?? "Choose a file"),
    );
  }
}

class TextWithIndent extends StatelessWidget {
  const TextWithIndent({super.key, required this.data, required this.indent, this.textAlign = TextAlign.start});
  

  final String data;
  final double indent;
  final TextAlign textAlign;

  TextSpan createWidget(BuildContext context) {
    final paragraphs = data.split("\n").expand((s) => [WidgetSpan(child: SizedBox(width: indent)), TextSpan(text: '$s\n')]);
    return TextSpan(
      style: Theme.of(context).textTheme.bodyMedium,
      children: paragraphs.toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: textAlign,
      text: createWidget(context)
    );
  }
}
