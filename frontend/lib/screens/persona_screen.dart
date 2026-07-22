import 'package:flutter/material.dart';
import '../api.dart';

class PersonaScreen extends StatefulWidget {
  @override
  _PersonaScreenState createState() => _PersonaScreenState();
}

class _PersonaScreenState extends State<PersonaScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _ageController = TextEditingController(text: "18");
  final _appearanceController = TextEditingController();
  final _personalityController = TextEditingController();
  final _backstoryController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPersona();
  }
  
  Future<void> _loadPersona() async {
    try {
      final persona = await ApiService.getPersona();
      if (persona != null && mounted) {
        setState(() {
          _nameController.text = persona['name'] ?? '';
          _ageController.text = persona['age']?.toString() ?? '18';
          _appearanceController.text = persona['appearance'] ?? '';
          _personalityController.text = persona['personality'] ?? '';
          _backstoryController.text = persona['backstory'] ?? '';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load Persona: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePersona() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    try {
      await ApiService.savePersona({
        'name': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text) ?? 18,
        'appearance': _appearanceController.text.trim(),
        'personality': _personalityController.text.trim(),
        'backstory': _backstoryController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Persona saved successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Roleplay Persona', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Create your Persona! AI Characters will remember these details about you and react to your unique traits.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    const SizedBox(height: 24),
                    
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Your Persona Name', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _ageController,
                      decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _appearanceController,
                      decoration: const InputDecoration(labelText: 'Physical Appearance', hintText: 'e.g. Tall, silver hair, green eyes...', border: OutlineInputBorder()),
                      maxLines: 3,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _personalityController,
                      decoration: const InputDecoration(labelText: 'Personality Traits', hintText: 'e.g. Sarcastic but loyal, easily flustered...', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _backstoryController,
                      decoration: const InputDecoration(labelText: 'Backstory / Secrets', hintText: 'e.g. I am secretly a vampire hunter...', border: OutlineInputBorder()),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 32),
                    
                    ElevatedButton(
                      onPressed: _isSaving ? null : _savePersona,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                          : const Text('Save Persona', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
