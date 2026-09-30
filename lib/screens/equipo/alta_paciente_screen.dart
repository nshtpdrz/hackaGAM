import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/api.dart';
import '../../core/api_modelos.dart';
import '../../core/state.dart';
import '../../core/sync.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../widgets/components.dart';
import '../shared.dart';
import '../auth/consentimiento_screen.dart';
import '../compartidas/perfil_form.dart' show AlergiasSelector;
import '../../core/validacion.dart';
import '../../core/tr.dart';

// 16. Alta de paciente: datos -> programa -> cuidador -> preferencias -> consentimiento -> QR.
class AltaPacienteScreen extends ConsumerStatefulWidget { const AltaPacienteScreen({super.key});
  @override ConsumerState<AltaPacienteScreen> createState() => _AltaState(); }
class _AltaState extends ConsumerState<AltaPacienteScreen> {
  static const titulos = ['Datos del paciente', 'Programa de cuidado', 'Cuidador responsable', 'Preferencias', 'QR de identificación'];
  int paso = 0; bool busy = false, audio = false, pict = false, grande = false; String? err, sexo, sangre, qr, lang = 'es'; Map? credenciales;
  DateTime? nac; final programas = <String>{}, alergias = <String>[]; final _c = <String, TextEditingController>{};
  TextEditingController t(String k) => _c.putIfAbsent(k, () => TextEditingController());
  @override
  void dispose() { for (final x in _c.values) { x.dispose(); } super.dispose(); }

  String? _validar() {
    if (paso == 0) {
      return validarNombre(t('nombre').text, campo: tr('el nombre del paciente')) ?? validarNacimiento(nac)
          ?? (sexo == null ? tr('Elige el sexo.') : null);
    }
    // Programa coherente con sexo y edad (el semáforo aplica reglas distintas por programa).
    if (paso == 1) return validarProgramas(programas, sexo: sexo, nacimiento: nac);
    if (paso == 2) {
      return validarNombre(t('cuidador').text, campo: tr('el nombre del cuidador'))
          ?? validarTelefono(t('contacto').text);
    }
    return null;
  }
  Future<void> _siguiente() async {
    final e = _validar(); if (e != null) { setState(() => err = e); return; }
    setState(() => err = null);
    if (paso < 3) { setState(() => paso++); return; }
    final firma = await context.push<String>('/consentimiento', extra: true);
    if (firma == null || !mounted) return;
    setState(() => busy = true);
    try {
      final api = ref.read(apiProvider);
      final aviso = await ref.read(avisoPrivacidadProvider.future).catchError((_) => const <String, dynamic>{});
      // El consentimiento debe citar la versión del aviso que se mostró; sin ella no se registra un consentimiento inventado.
      final version = aviso['version']?.toString();
      if (version == null || version.isEmpty) {
        if (mounted) setState(() { busy = false; err = tr('No se pudo obtener la versión del aviso de privacidad. Revisa la conexión e intenta de nuevo.'); });
        return;
      }
      // POST /pacientes: perfil + programas + cuidador + consentimiento -> paciente + codigo_qr + credenciales temporales.
      final p = await api.crearPaciente({'nombre': t('nombre').text.trim().replaceAll(RegExp(r'\s+'), ' '),
        'fecha_nacimiento': nac!.toIso8601String().substring(0, 10),
        'sexo': sexo, 'tipo_sangre': sangre == 'No sé' ? null : sangre, 'alergias': alergias.join(', '), 'diagnosticos': t('diagnosticos').text.trim(),
        'programas': programas.toList(), 'cuidador': {'nombre': t('cuidador').text.trim().replaceAll(RegExp(r'\s+'), ' '),
          'contacto': soloDigitos(t('contacto').text)}},
        versionAviso: version);
      final id = '${p['id']}';
      // La guía solo permite PUT preferencias al paciente y al cuidador: si el equipo no puede, se omite
      // (el paciente las ajusta al entrar).
      try {
        await api.guardarPreferencias(id, Prefs(lang: lang!, audio: audio, pictograms: pict, bigButtons: grande, textScale: grande ? 1.4 : 1.0).toJson());
      } catch (_) {}
      ref.invalidate(futureFor('pacientes'));
      if (mounted) setState(() { qr = '${p['codigo_qr'] ?? ''}'; credenciales = p['credenciales'] as Map?; paso = 4; busy = false; });
    } catch (e) {
      if (mounted) setState(() { busy = false; err = isNetworkError(e) ? tr('Sin conexión. El alta necesita internet.')
          : mensajeError(e) ?? tr('No se pudo dar de alta. Intenta de nuevo.'); });
    }
  }

  Widget _cuerpo() {
    switch (paso) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppField(t('nombre'), tr('Nombre completo'), maxLength: 100), SectionLabel(tr('Fecha de nacimiento')),
          OutlinedButton.icon(icon: const Icon(Icons.calendar_today), label: Text(nac == null ? tr('Elegir fecha') : fmtFecha(nac!)), onPressed: () async {
            final d = await showDatePicker(context: context, initialDate: DateTime(1970), firstDate: DateTime(1900), lastDate: DateTime.now(),
              builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(textScaler: MediaQuery.textScalerOf(ctx).clamp(maxScaleFactor: 1.3)), child: child!));
            if (d != null) setState(() => nac = d); }),
          SectionLabel(tr('Sexo')), ChoiceWrap(options: {'F': tr('Mujer'), 'M': tr('Hombre')}, isSel: (k) => sexo == k, onTap: (k) => setState(() => sexo = k)),
          SectionLabel(tr('Tipo de sangre')), ChoiceWrap(options: {for (final s in tiposSangre) s: s}, isSel: (k) => sangre == k, onTap: (k) => setState(() => sangre = k)),
          SectionLabel(tr('Alergias a medicamentos')), AlergiasSelector(alergias: alergias, onChanged: () => setState(() {})),
          AppField(t('diagnosticos'), tr('Diagnósticos (opcional)'), maxLength: 300)]);
      case 1:
        return ChoiceWrap(options: programasCuidado, isSel: programas.contains, onTap: (k) => setState(() => programas.contains(k) ? programas.remove(k) : programas.add(k)));
      case 2:
        return Column(children: [AppField(t('cuidador'), tr('Nombre del cuidador'), maxLength: 100),
          AppField(t('contacto'), tr('Teléfono del cuidador (10 dígitos, opcional)'), kt: TextInputType.phone, maxLength: 16,
            formatos: [FilteringTextInputFormatter.allow(RegExp(r'[\d +()-]'))], ayuda: tr('Para que el equipo de salud pueda localizarlo.'))]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionLabel(tr('Idioma')), ChoiceWrap(options: langs, isSel: (k) => lang == k, onTap: (k) => setState(() => lang = k)),
          SwitchListTile(title: Text(tr('Prefiere escuchar audios')), value: audio, onChanged: (v) => setState(() => audio = v)),
          SwitchListTile(title: Text(tr('Prefiere pictogramas')), value: pict, onChanged: (v) => setState(() => pict = v)),
          SwitchListTile(title: Text(tr('Letra grande y botones grandes')), value: grande, onChanged: (v) => setState(() => grande = v))]);
      default:
        return Column(children: [
          Semantics(label: tr('Código QR de identificación del paciente'), child: QrImageView(data: qr!, size: 240, backgroundColor: Colors.white)),
          Padding(padding: const EdgeInsets.all(16), child: Text(tr('Entrega este código al paciente para identificarlo en consulta.'), textAlign: TextAlign.center)),
          // Credenciales temporales: la API las devuelve UNA sola vez.
          if (credenciales != null && credenciales!.isNotEmpty) InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.key, color: C.warning), const SizedBox(width: 8),
              Expanded(child: Text(tr('Acceso temporal del paciente'), style: Theme.of(context).textTheme.titleMedium))]),
            const SizedBox(height: 8),
            for (final e in credenciales!.entries) SelectableText('${tr(e.key == 'correo' ? 'Correo' : e.key == 'contrasena' ? 'Contraseña temporal' : '${e.key}')}: ${e.value}'),
            const SizedBox(height: 8),
            Text(tr('Anótalas y entrégalas al paciente: solo se muestran esta vez.'), style: const TextStyle(color: C.warning, fontWeight: FontWeight.w600))]))]);
    }
  }

  @override
  Widget build(BuildContext c) => page(c, tr(titulos[paso]), SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(label: tr('Paso {n} de {t}', {'n': paso + 1, 't': 5}), child: LinearProgressIndicator(value: (paso + 1) / 5, minHeight: 10)),
      const SizedBox(height: 16), Expanded(child: SingleChildScrollView(child: _cuerpo())),
      if (err != null) Semantics(liveRegion: true, child: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(err!, style: const TextStyle(color: C.error)))),
      if (paso < 4) Row(children: [
        if (paso > 0) Expanded(child: BigButton(tr('Anterior'), icon: Icons.arrow_back, secondary: true, onTap: () => setState(() => paso--))),
        if (paso > 0) const SizedBox(width: 12),
        Expanded(child: BigButton(paso == 3 ? tr('Firmar y dar de alta') : tr('Siguiente'), onTap: busy ? null : _siguiente))])
      else BigButton(tr('Listo'), onTap: () => c.go('/pacientes'))]))), bell: false);
}
