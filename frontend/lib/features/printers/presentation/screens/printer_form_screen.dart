import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/responsive_wrapper.dart';
import '../../domain/printer.dart';
import '../../providers/printer_providers.dart';

class PrinterFormScreen extends ConsumerStatefulWidget {
  final String? printerId;

  const PrinterFormScreen({super.key, this.printerId});

  bool get isEdit => printerId != null && printerId!.isNotEmpty;

  @override
  ConsumerState<PrinterFormScreen> createState() => _PrinterFormScreenState();
}

class _PrinterFormScreenState extends ConsumerState<PrinterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _modelController = TextEditingController();
  final _buildXController = TextEditingController();
  final _buildYController = TextEditingController();
  final _buildZController = TextEditingController();
  final _connectionUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _materialsController = TextEditingController();

  PrinterTechnology _technology = PrinterTechnology.fdm;
  PrinterConnectorType _connectorType = PrinterConnectorType.mock;
  PrinterStatusValue _status = PrinterStatusValue.offline;

  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    _buildXController.dispose();
    _buildYController.dispose();
    _buildZController.dispose();
    _connectionUrlController.dispose();
    _apiKeyController.dispose();
    _materialsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(isAdminProvider);
    if (isAdminAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isAdmin = isAdminAsync.value ?? false;

    if (!isAdmin) {
      return _buildAccessDenied(context);
    }

    if (widget.isEdit) {
      final printerAsync = ref.watch(printerDetailProvider(widget.printerId!));
      return printerAsync.when(
        data: (printer) {
          _initializeFromPrinter(printer);
          return _buildForm(context);
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      );
    }

    return _buildForm(context);
  }

  Widget _buildAccessDenied(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Admin Only',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: const Center(
        child: Text(
          'You need admin access to manage printers.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.isEdit ? 'Edit Printer' : 'Add Printer',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveWrapper(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Basics'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Printer name',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'Model (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PrinterTechnology>(
                    value: _technology,
                    items: PrinterTechnology.values
                        .map(
                          (tech) => DropdownMenuItem(
                            value: tech,
                            child: Text(_technologyLabel(tech)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _technology = value);
                    },
                    decoration: const InputDecoration(labelText: 'Technology'),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Build Volume (mm)'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _buildXController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(labelText: 'X'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _buildYController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(labelText: 'Y'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _buildZController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(labelText: 'Z'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Connection'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PrinterConnectorType>(
                    value: _connectorType,
                    items: PrinterConnectorType.values
                        .map(
                          (connector) => DropdownMenuItem(
                            value: connector,
                            child: Text(_connectorLabel(connector)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _connectorType = value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Connector type',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_requiresConnectionDetails(_connectorType)) ...[
                    TextFormField(
                      controller: _connectionUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Connection URL',
                        hintText: 'https://printer.local or http://ip:port',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(
                        labelText: 'API key',
                        hintText: 'Stored securely (never shown after save)',
                      ),
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Leave API key empty to keep the current one.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _sectionTitle('Materials'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _materialsController,
                    decoration: const InputDecoration(
                      labelText: 'Materials supported',
                      hintText: 'PLA, PETG, ABS',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Status'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PrinterStatusValue>(
                    value: _status,
                    items: PrinterStatusValue.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_statusLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _status = value);
                    },
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.isEdit ? 'Save changes' : 'Create printer',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _initializeFromPrinter(Printer printer) {
    if (_initialized) return;

    _nameController.text = printer.name;
    _modelController.text = printer.model ?? '';
    _buildXController.text = printer.buildVolumeX?.toString() ?? '';
    _buildYController.text = printer.buildVolumeY?.toString() ?? '';
    _buildZController.text = printer.buildVolumeZ?.toString() ?? '';
    _materialsController.text = printer.materialsSupported?.join(', ') ?? '';

    _technology = printer.technology;
    _connectorType = printer.connectorType;
    _status = printer.status;

    _initialized = true;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(printerRepositoryProvider);
      if (widget.isEdit) {
        await repo.updatePrinter(
          id: widget.printerId!,
          payload: _buildUpdatePayload(),
        );
        ref.invalidate(printersListProvider);
        ref.invalidate(printerDetailProvider(widget.printerId!));
        if (mounted) {
          _showSnack('Printer updated', AppColors.success);
          context.go('${AppRoutes.fleet}/${widget.printerId}');
        }
      } else {
        final created = await repo.createPrinter(_buildCreatePayload());
        ref.invalidate(printersListProvider);
        if (mounted) {
          _showSnack('Printer created', AppColors.success);
          context.go('${AppRoutes.fleet}/${created.id}');
        }
      }
    } catch (error) {
      if (mounted) {
        _showSnack(_readableError(error), AppColors.error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  PrinterCreate _buildCreatePayload() {
    return PrinterCreate(
      name: _nameController.text.trim(),
      model: _modelController.text.trim().isEmpty
          ? null
          : _modelController.text.trim(),
      technology: _technology,
      buildVolumeX: _toDouble(_buildXController.text),
      buildVolumeY: _toDouble(_buildYController.text),
      buildVolumeZ: _toDouble(_buildZController.text),
      connectorType: _connectorType,
      connectionUrl: _textOrNull(_connectionUrlController.text),
      status: _status,
      materialsSupported: _parseMaterials(),
      apiKey: _textOrNull(_apiKeyController.text),
    );
  }

  PrinterUpdate _buildUpdatePayload() {
    final apiKey = _textOrNull(_apiKeyController.text);
    final connectionUrl = _textOrNull(_connectionUrlController.text);

    return PrinterUpdate(
      name: _nameController.text.trim(),
      model: _textOrNull(_modelController.text),
      technology: _technology,
      buildVolumeX: _toDouble(_buildXController.text),
      buildVolumeY: _toDouble(_buildYController.text),
      buildVolumeZ: _toDouble(_buildZController.text),
      connectorType: _connectorType,
      connectionUrl: connectionUrl,
      status: _status,
      materialsSupported: _parseMaterials(),
      apiKey: apiKey,
    );
  }

  List<String>? _parseMaterials() {
    final text = _materialsController.text.trim();
    if (text.isEmpty) return null;
    final values = text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return values.isEmpty ? null : values;
  }

  double? _toDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  String? _textOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _requiresConnectionDetails(PrinterConnectorType connector) {
    return connector == PrinterConnectorType.octoprint ||
        connector == PrinterConnectorType.prusalink;
  }

  String _technologyLabel(PrinterTechnology tech) {
    switch (tech) {
      case PrinterTechnology.fdm:
        return 'FDM';
      case PrinterTechnology.sla:
        return 'SLA';
    }
  }

  String _connectorLabel(PrinterConnectorType connector) {
    switch (connector) {
      case PrinterConnectorType.octoprint:
        return 'OctoPrint';
      case PrinterConnectorType.prusalink:
        return 'PrusaLink';
      case PrinterConnectorType.mock:
        return 'Mock';
      case PrinterConnectorType.manual:
        return 'Manual';
    }
  }

  String _statusLabel(PrinterStatusValue status) {
    switch (status) {
      case PrinterStatusValue.idle:
        return 'Idle';
      case PrinterStatusValue.printing:
        return 'Printing';
      case PrinterStatusValue.error:
        return 'Error';
      case PrinterStatusValue.offline:
        return 'Offline';
      case PrinterStatusValue.maintenance:
        return 'Maintenance';
    }
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _readableError(Object error) {
    final text = error.toString();
    return text.replaceFirst('Exception: ', '');
  }
}
