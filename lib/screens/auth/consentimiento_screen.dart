import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/components.dart';
import '../../core/tr.dart';

/// GET /aviso-privacidad (público) -> {version, texto}. La versión viaja en el consentimiento del alta.
final avisoPrivacidadProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final r = await ref.read(apiProvider).avisoPrivacidad();
  return r is Map ? r.cast<String, dynamic>() : const {};
});

// Consentimiento y privacidad. Devuelve el nombre firmado (String) si acepta; null si no.
// Los textos vienen del catálogo (consent.privacidad / consent.informado): sustituir por los oficiales.
class ConsentimientoScreen extends ConsumerStatefulWidget { final bool tutor;
  const ConsentimientoScreen({super.key, this.tutor = false});
  @override ConsumerState<ConsentimientoScreen> createState() => _ConsentState(); }
class _ConsentState extends ConsumerState<ConsentimientoScreen> {
  bool priv = false, info = false; final _firma = TextEditingController();
  @override
  void dispose() { _firma.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) {
    // Sin la versión del aviso (no cargó) no se puede aceptar: el alta debe registrar qué versión se aceptó.
    final aviso = ref.watch(avisoPrivacidadProvider);
    final hayVersion = aviso.valueOrNull?['version'] != null;
    final listo = hayVersion && priv && info && _firma.text.trim().length >= 3;
    final h = Theme.of(c).textTheme.headlineSmall;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Privacidad y consentimiento')), backgroundColor: C.bg),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        Text(tr('Aviso de privacidad'), style: h), const SizedBox(height: 8),
        // Texto oficial de la API si existe; si no, el provisional del catálogo.
        aviso.when(
          data: (a) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (a['texto'] == null) const MsgText('consent.privacidad') else Text('${a['texto']}', style: Theme.of(c).textTheme.bodyLarge),
            if (a['version'] != null) Text(tr('Versión {v}', {'v': a['version']}), style: Theme.of(c).textTheme.bodySmall)
            else Text(tr('No se recibió la versión del aviso de privacidad. Intenta más tarde.'), style: const TextStyle(color: C.error))]),
          loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          error: (_, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('No se pudo cargar el aviso de privacidad. Sin él no se puede continuar.'), style: const TextStyle(color: C.error)),
            TextButton.icon(onPressed: () => ref.invalidate(avisoPrivacidadProvider), icon: const Icon(Icons.refresh), label: Text(tr('Reintentar')))])),
        CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: priv,
          onChanged: (v) => setState(() => priv = v ?? false), title: Text(tr('He leído el aviso de privacidad'))),
        const SizedBox(height: 16), Text(tr('Consentimiento informado'), style: h), const SizedBox(height: 8), const MsgText('consent.informado'),
        CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: info,
          onChanged: (v) => setState(() => info = v ?? false), title: Text(tr('Acepto el seguimiento de mi salud en esta app'))),
        SectionLabel(widget.tutor ? tr('Firma del paciente o su representante') : tr('Tu firma')),
        TextField(controller: _firma, onChanged: (_) => setState(() {}), textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: tr('Escribe tu nombre completo'))),
        const SizedBox(height: 24),
        BigButton(tr('Aceptar y continuar'), onTap: listo ? () => c.pop(_firma.text.trim()) : null),
        const SizedBox(height: 12), BigButton(tr('No acepto'), secondary: true, onTap: () => c.pop())])));
  }
}
