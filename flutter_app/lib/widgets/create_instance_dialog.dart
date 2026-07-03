// Create emulator instance dialog.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:adb_tool/providers/emulator_image_provider.dart';
import 'package:adb_tool/providers/emulator_instance_provider.dart';

class CreateInstanceDialog extends StatefulWidget {
  const CreateInstanceDialog({super.key});

  @override
  State<CreateInstanceDialog> createState() => _CreateInstanceDialogState();
}

class _CreateInstanceDialogState extends State<CreateInstanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _selectedImageId;
  int _cores = 4;
  int _memoryMb = 4096;
  int _width = 1080;
  int _height = 1920;
  int _density = 420;
  String _gpuMode = 'auto';
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Emulator Instance'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Instance name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Instance Name',
                    hintText: 'e.g., my-emulator',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    if (value.contains(RegExp(r'[ ./\\:*?"<>|]'))) {
                      return 'Name cannot contain special characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // System image selection
                const Text('System Image', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Consumer<EmulatorImageProvider>(
                  builder: (context, provider, _) {
                    final images = provider.readyImages;
                    if (images.isEmpty) {
                      return const Text(
                        'No system images available. Please download one first.',
                        style: TextStyle(color: Colors.orange),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedImageId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Select a system image',
                      ),
                      items: images.map((img) {
                        return DropdownMenuItem(
                          value: img.id,
                          child: Text('${img.name} (API ${img.apiLevel})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedImageId = value;
                          // Auto-fill dimensions based on image. Guard
                          // against the image disappearing between the
                          // dropdown render and the user's click (e.g.
                          // another tab deleted it) — without orElse
                          // firstWhere would throw StateError and break
                          // the dialog.
                          if (value != null) {
                            final image = images
                                .where((i) => i.id == value)
                                .firstOrNull;
                            if (image != null) {
                              _density = _getDensityFromVariant(image.variant);
                            }
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a system image';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Hardware configuration
                const Text('Hardware Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                // CPU cores
                Row(
                  children: [
                    const Expanded(child: Text('CPU Cores:')),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<int>(
                        value: _cores,
                        isExpanded: true,
                        items: [1, 2, 4, 8].map((c) {
                          return DropdownMenuItem(value: c, child: Text('$c'));
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _cores = value ?? 4);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Memory
                Row(
                  children: [
                    const Expanded(child: Text('Memory (MB):')),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<int>(
                        value: _memoryMb,
                        isExpanded: true,
                        items: [2048, 4096, 6144, 8192].map((m) {
                          return DropdownMenuItem(value: m, child: Text('$m MB'));
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _memoryMb = value ?? 4096);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Resolution
                const Text('Resolution'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _width.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Width',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (value) {
                          _width = int.tryParse(value) ?? 1080;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('×'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: _height.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Height',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (value) {
                          _height = int.tryParse(value) ?? 1920;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Density presets
                Row(
                  children: [
                    const Expanded(child: Text('Density:')),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<int>(
                        value: _density,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(value: 160, child: Text('mdpi (160)')),
                          const DropdownMenuItem(value: 240, child: Text('hdpi (240)')),
                          const DropdownMenuItem(value: 320, child: Text('xhdpi (320)')),
                          const DropdownMenuItem(value: 420, child: Text('xxhdpi (420)')),
                          const DropdownMenuItem(value: 560, child: Text('xxxhdpi (560)')),
                        ],
                        onChanged: (value) {
                          setState(() => _density = value ?? 420);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // GPU mode
                Row(
                  children: [
                    const Expanded(child: Text('GPU:')),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        value: _gpuMode,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'auto', child: Text('Auto')),
                          DropdownMenuItem(value: 'host', child: Text('Host (GPU)')),
                          DropdownMenuItem(value: 'swiftshader_indirect', child: Text('Software')),
                          DropdownMenuItem(value: 'off', child: Text('Off')),
                        ],
                        onChanged: (value) {
                          setState(() => _gpuMode = value ?? 'auto');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createInstance,
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  int _getDensityFromVariant(String? variant) {
    switch (variant?.toLowerCase()) {
      case 'google_apis/x86':
      case 'google_apis/x86_64':
      case 'google_apis/arm64-v8a':
        return 420; // xxhdpi
      case 'default/x86':
      case 'default/x86_64':
      case 'default/arm64-v8a':
        return 420;
      default:
        return 420;
    }
  }

  Future<void> _createInstance() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    final provider = context.read<EmulatorInstanceProvider>();
    final instance = await provider.createNewInstance(
      name: _nameController.text.trim(),
      imageId: _selectedImageId!,
      cores: _cores,
      memoryMb: _memoryMb,
      width: _width,
      height: _height,
      density: _density,
      gpuMode: _gpuMode,
    );

    if (!mounted) return;

    setState(() => _isCreating = false);

    if (instance != null) {
      Navigator.pop(context, instance);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Instance "${instance.avdName}" created')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create instance: ${provider.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
