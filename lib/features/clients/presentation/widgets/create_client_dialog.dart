import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sendzyy/core/theme/app_theme.dart';
import 'package:sendzyy/features/clients/data/models/client_model.dart';
import 'package:sendzyy/features/clients/presentation/bloc/client_bloc.dart';

class CreateClientDialog extends StatefulWidget {
  final VoidCallback? onSaved;
  const CreateClientDialog({super.key, this.onSaved});

  @override
  State<CreateClientDialog> createState() => _CreateClientDialogState();
}

class _CreateClientDialogState extends State<CreateClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _companyController = TextEditingController();
  final _emailController = TextEditingController();
  final _venueController = TextEditingController();
  final _remarkController = TextEditingController();
  bool _isSubmitting = false;
  bool _saveHandled = false; // prevents listener from firing on subsequent state changes

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    _venueController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSubmitting = true;
        _saveHandled = false;
      });

      final client = ClientModel(
        id: '',
        tenantId: '',
        name: _nameController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        companyName: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
        emailId: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        venue: _venueController.text.trim(),
        remark: _remarkController.text.trim().isEmpty ? null : _remarkController.text.trim(),
        createdAt: DateTime.now(),
      );

      context.read<ClientsBloc>().add(CreateClient(client));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ClientsBloc, ClientsState>(
      listener: (context, state) {
        if (_isSubmitting && !_saveHandled) {
          if (state is ClientsError) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          } else if (state is ClientsLoaded) {
            _saveHandled = true; // stop listening for further state changes
            _isSubmitting = false;
            Navigator.of(context).pop();
            widget.onSaved?.call();
          }
        }
      },
      builder: (context, state) {
        final isLoading = state is ClientsLoading;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Create New Client',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                      hintText: 'With country code (e.g. 919876543210)',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Required';
                      final digits = val.trim();
                      if (!RegExp(r'^\d{10,15}$').hasMatch(digits)) {
                        return 'Enter a valid mobile number (10–15 digits, with country code)';
                      }
                      final s = context.read<ClientsBloc>().state;
                      if (s is ClientsLoaded) {
                        if (s.filteredClients.any((c) => c.mobileNumber == digits)) {
                          return 'Number already exists';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _companyController,
                    decoration: const InputDecoration(
                      labelText: 'Company Name (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email ID (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return null; // optional
                      if (!RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(val.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _venueController,
                    decoration: const InputDecoration(
                      labelText: 'Venue *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Venue is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _remarkController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Remark (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Save Client'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

