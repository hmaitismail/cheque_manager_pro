import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class FichierChoisi {
  final String chemin;
  final String nom;
  FichierChoisi(this.chemin, this.nom);
  bool get estPdf => chemin.toLowerCase().endsWith('.pdf');
}

/// Propose : appareil photo, galerie ou document PDF.
Future<FichierChoisi?> choisirPiece(
  BuildContext context, {
  String titre = 'Ajouter une pièce jointe',
}) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(titre, style: Theme.of(ctx).textTheme.titleMedium),
        ),
        ListTile(
          leading: const Icon(Icons.photo_camera),
          title: const Text('Photographier le chèque'),
          onTap: () => Navigator.pop(ctx, 'camera'),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: const Text('Importer depuis la galerie'),
          onTap: () => Navigator.pop(ctx, 'galerie'),
        ),
        ListTile(
          leading: const Icon(Icons.picture_as_pdf),
          title: const Text('Joindre un document PDF'),
          onTap: () => Navigator.pop(ctx, 'pdf'),
        ),
        const SizedBox(height: 12),
      ],
    ),
  );
  if (source == null) return null;
  try {
    if (source == 'pdf') {
      final r = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (r.isEmpty || r.first.path == null) return null;
      return FichierChoisi(r.first.path!, r.first.name);
    }
    final img = await ImagePicker().pickImage(
      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2400,
    );
    if (img == null) return null;
    final nom = source == 'camera'
        ? 'Photo du ${DateTime.now().toString().substring(0, 16)}'
        : p.basename(img.path);
    return FichierChoisi(img.path, nom);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'accéder au fichier : $e')),
      );
    }
    return null;
  }
}
