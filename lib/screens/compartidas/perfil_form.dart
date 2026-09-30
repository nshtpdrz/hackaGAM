import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../core/validacion.dart';
import '../../core/api_modelos.dart' show programaApi;
import '../../widgets/components.dart';
import '../shared.dart';
import '../../core/tr.dart';
import '../../widgets/dialogs.dart';

/// Datos del perfil. Un solo modelo para "Crear cuenta" y "Editar perfil",
/// así ambos formularios piden y envían exactamente los mismos campos.
class DatosPerfil {
  final nombre = TextEditingController(), correo = TextEditingController(),
      telefono = TextEditingController();
  final alergias = <String>[]; // alergias a fármacos
  DateTime? nacimiento; String? sexo, sangre; final programas = <String>{};
  String etapaEmbarazo = 'embarazo'; // 'embarazo' | 'puerperio' (solo si el programa es embarazo)

  DatosPerfil([Map? p]) {
    if (p == null) return;
    nombre.text = '${p['nombre'] ?? ''}'; correo.text = '${p['correo'] ?? ''}';
    telefono.text = '${p['telefono'] ?? ''}'; alergias.addAll(listaAlergias(p['alergias']));
    nacimiento = DateTime.tryParse('${p['fecha_nacimiento'] ?? ''}');
    sexo = p['sexo'] as String?; sangre = p['tipo_sangre'] as String?;
    programas.addAll([for (final k in (p['programas'] as List? ?? const [])) '$k']);
    if (p['etapa_embarazo'] == 'puerperio') etapaEmbarazo = 'puerperio';
  }
  void dispose() { for (final c in [nombre, correo, telefono]) { c.dispose(); } }

  String? validar({required bool paciente}) {
    final e = validarNombre(nombre.text) ?? validarCorreo(correo.text) ?? validarTelefono(telefono.text);
    if (e != null || !paciente) return e;
    if (sexo == null) return tr('Elige el sexo.');
    return validarNacimiento(nacimiento) ?? validarProgramas(programas, sexo: sexo, nacimiento: nacimiento);
  }

  /// Datos de la cuenta (todos los roles). Nombre sin espacios dobles, correo en minúsculas, teléfono solo dígitos.
  Map<String, dynamic> contacto() => {'nombre': nombre.text.trim().replaceAll(RegExp(r'\s+'), ' '),
    'correo': correo.text.trim().toLowerCase(), 'telefono': soloDigitos(telefono.text)};
  /// Datos clínicos básicos (solo paciente).
  /// Los programas van con el nombre del servidor (cronicas, embarazo_puerperio…), igual que en POST /pacientes.
  Map<String, dynamic> clinicos() => {'fecha_nacimiento': nacimiento!.toIso8601String().substring(0, 10),
    'sexo': sexo, if (sangre != null && sangre != 'No sé') 'tipo_sangre': sangre, 'alergias': [...alergias],
    'programas': [for (final p in programas) {'programa': programaApi(p)}],
    if (programas.contains('embarazo')) 'etapa_embarazo': etapaEmbarazo};
}

/// Campos del perfil. [despuesDeCorreo] permite insertar campos propios del registro (p. ej. contraseña).
class DatosPerfilForm extends StatefulWidget {
  final DatosPerfil datos; final bool paciente; final List<Widget> despuesDeCorreo;
  const DatosPerfilForm({super.key, required this.datos, required this.paciente, this.despuesDeCorreo = const []});
  @override State<DatosPerfilForm> createState() => _DatosPerfilFormState(); }

class _DatosPerfilFormState extends State<DatosPerfilForm> {
  @override
  Widget build(BuildContext c) {
    final d = widget.datos;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppField(d.nombre, tr('Nombre completo'), maxLength: 100, autofill: const [AutofillHints.name]),
      AppField(d.correo, tr('Correo electrónico'), kt: TextInputType.emailAddress, maxLength: 254,
        autofill: const [AutofillHints.email], formatos: [FilteringTextInputFormatter.deny(RegExp(r'\s'))]),
      ...widget.despuesDeCorreo,
      AppField(d.telefono, tr('Teléfono (10 dígitos, opcional)'), kt: TextInputType.phone, maxLength: 16,
        autofill: const [AutofillHints.telephoneNumber], formatos: [FilteringTextInputFormatter.allow(RegExp(r'[\d +()-]'))]),
      if (widget.paciente) ...[
        SectionLabel(tr('Fecha de nacimiento')),
        OutlinedButton.icon(icon: const Icon(Icons.calendar_today), label: Text(d.nacimiento == null ? tr('Elegir fecha') : fmtFecha(d.nacimiento!)),
          onPressed: () async {
            final f = await showDatePicker(context: context, initialDate: d.nacimiento ?? DateTime(1980), firstDate: DateTime(1900), lastDate: DateTime.now(),
              // El calendario de Material se desborda con letra mayor a 1.3x: se limita solo dentro del selector.
              builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(
                  textScaler: MediaQuery.textScalerOf(ctx).clamp(maxScaleFactor: 1.3)), child: child!));
            if (f != null) setState(() => d.nacimiento = f); }),
        SectionLabel(tr('Sexo')),
        ChoiceWrap(options: {'F': tr('Mujer'), 'M': tr('Hombre')}, isSel: (k) => d.sexo == k, onTap: (k) => setState(() => d.sexo = k)),
        SectionLabel(tr('Tipo de sangre')),
        ChoiceWrap(options: {for (final s in tiposSangre) s: tr(s)}, isSel: (k) => d.sangre == k, onTap: (k) => setState(() => d.sangre = k)),
        SectionLabel(tr('Alergias a medicamentos')),
        AlergiasSelector(alergias: d.alergias, onChanged: () => setState(() {})),
        SectionLabel(tr('Programa de seguimiento (elige uno o más)')),
        for (final e in programasCuidado.entries) ...[
          CheckboxListTile(contentPadding: EdgeInsets.zero, title: Text(tr(e.value)), value: d.programas.contains(e.key),
            onChanged: (v) => setState(() => v! ? d.programas.add(e.key) : d.programas.remove(e.key))),
          if (e.key == 'embarazo' && d.programas.contains('embarazo')) Padding(padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Card(child: RadioGroup<String>(groupValue: d.etapaEmbarazo, onChanged: (v) => setState(() => d.etapaEmbarazo = v!),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: EdgeInsets.only(left: 16, top: 12), child: Text(tr('¿En qué etapa te encuentras?'), style: TextStyle(fontWeight: FontWeight.bold))),
                RadioListTile<String>(title: Text(tr('Embarazo')), value: 'embarazo'),
                RadioListTile<String>(title: Text(tr('Puerperio (postparto - primeros 42 días)')), value: 'puerperio')]))))]]]);
  }
}

/// Lista desplegable de alergias a fármacos. Cada elección se agrega como chip (se pueden agregar varias);
/// la última opción, "Otro medicamento…", permite escribir uno que no está en el catálogo.
class AlergiasSelector extends StatefulWidget {
  final List<String> alergias; final VoidCallback onChanged;
  const AlergiasSelector({super.key, required this.alergias, required this.onChanged});
  @override State<AlergiasSelector> createState() => _AlergiasSelectorState(); }

String _norm(String s) => s.toLowerCase().replaceAll(RegExp('[áä]'), 'a').replaceAll(RegExp('[éë]'), 'e')
    .replaceAll(RegExp('[íï]'), 'i').replaceAll(RegExp('[óö]'), 'o').replaceAll(RegExp('[úü]'), 'u');

class _AlergiasSelectorState extends State<AlergiasSelector> {
  static const _otro = '__otro__';
  int _reinicio = 0; // cambia la key para que la lista vuelva a "sin elegir" tras cada alta

  Future<void> _elegir(String? v) async {
    if (v == null) return;
    final escrito = v == _otro ? await _pedirOtro() : v;
    if (!mounted) return;
    setState(() => _reinicio++);
    final t = (escrito ?? '').trim();
    // Si lo escrito coincide con el catálogo, se guarda con el nombre del catálogo.
    final a = alergiasFarmacos.firstWhere((x) => _norm(x) == _norm(t), orElse: () => t);
    if (a.isEmpty || widget.alergias.any((x) => _norm(x) == _norm(a))) return;
    widget.alergias.add(a); widget.onChanged();
  }

  Future<String?> _pedirOtro() => showDialog<String>(context: context, builder: (_) => const _OtroMedicamentoDialog());

  @override
  Widget build(BuildContext c) {
    final opciones = alergiasFarmacos.where((a) => !widget.alergias.contains(a));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DropdownButtonFormField<String>(key: ValueKey(_reinicio), isExpanded: true, menuMaxHeight: 360,
        decoration: InputDecoration(labelText: tr('Agregar alergia'), prefixIcon: Icon(Icons.medication_outlined),
          helperText: tr('Puedes agregar varias. ¿No está? Elige "Otro medicamento…".'), helperMaxLines: 4),
        items: [
          for (final a in opciones) DropdownMenuItem(value: a, child: Text(a, overflow: TextOverflow.ellipsis)),
          DropdownMenuItem(value: _otro, child: Row(children: [Icon(Icons.add_circle_outline, color: C.primary),
            SizedBox(width: 8), Flexible(child: Text(tr('Otro medicamento…'), style: TextStyle(fontWeight: FontWeight.w600)))]))],
        onChanged: _elegir),
      const SizedBox(height: 12),
      if (widget.alergias.isEmpty)
        Text(tr('Sin alergias registradas. Déjalo vacío si no tienes alergias a medicamentos.'))
      else
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in widget.alergias) InputChip(label: Text(a), avatar: const Icon(Icons.warning_amber_rounded, size: 18),
            deleteButtonTooltipMessage: tr('Quitar {a}', {'a': a}), onDeleted: () { widget.alergias.remove(a); widget.onChanged(); })]),
      const SizedBox(height: 16)]);
  }
}

/// Diálogo para escribir un medicamento fuera del catálogo. Es dueño de su controlador
/// (se libera al desmontarse, después de la animación de cierre).
class _OtroMedicamentoDialog extends StatefulWidget { const _OtroMedicamentoDialog();
  @override State<_OtroMedicamentoDialog> createState() => _OtroMedicamentoDialogState(); }

class _OtroMedicamentoDialogState extends State<_OtroMedicamentoDialog> {
  final _ctl = TextEditingController();
  @override
  void dispose() { _ctl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) => DialogoAdaptable(
    titulo: Text(tr('Otro medicamento')),
    contenido: TextField(controller: _ctl, autofocus: true, textCapitalization: TextCapitalization.sentences, maxLength: 60,
      decoration: InputDecoration(labelText: tr('Nombre del medicamento')), onSubmitted: (v) => Navigator.pop(c, v)),
    acciones: [TextButton(style: estiloBotonDialogo, onPressed: () => Navigator.pop(c), child: Text(tr('Cancelar'))),
      FilledButton(style: estiloBotonDialogo, onPressed: () => Navigator.pop(c, _ctl.text), child: Text(tr('Agregar')))]);
}
