import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/permisos.dart';
import '../core/sync.dart';
import '../core/theme.dart';
import '../core/tr.dart';
import 'dialogs.dart';

/// Lector de QR con respaldo manual (sin cámara o en web se escribe el código).
/// [onCodigo] se llama una sola vez por lectura; mientras corre no se aceptan otras.
/// Si lanza una excepción se muestra el error y se puede volver a escanear.
class LectorQr extends StatefulWidget {
  final Future<void> Function(String codigo) onCodigo; final String instruccion;
  const LectorQr({super.key, required this.onCodigo, this.instruccion = 'Apunta la cámara al código QR del paciente.'});
  @override State<LectorQr> createState() => _LectorQrState(); }

class _LectorQrState extends State<LectorQr> {
  bool busy = false; String? error;

  Future<void> _procesar(String? codigo) async {
    final c = codigo?.trim() ?? '';
    if (busy || c.isEmpty) return;
    setState(() { busy = true; error = null; });
    try {
      await widget.onCodigo(c);
    } catch (e) {
      if (mounted) setState(() => error = isNetworkError(e) ? tr('Sin conexión. Revisa tu internet e intenta de nuevo.')
          : tr('Código no válido o paciente no encontrado.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _manual() async => _procesar(await showDialog<String>(context: context, builder: (_) => const _CodigoDialog()));

  @override
  Widget build(BuildContext c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Expanded(child: Stack(fit: StackFit.expand, children: [
      MobileScanner(onDetect: (cap) => _procesar(cap.barcodes.firstOrNull?.rawValue),
        errorBuilder: (_, e, __) {
          final permiso = e.errorCode == MobileScannerErrorCode.permissionDenied;
          return ColoredBox(color: Colors.black87, child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.no_photography_outlined, color: Colors.white, size: 48), const SizedBox(height: 12),
              Text(permiso ? tr('SENDA no tiene permiso de usar la cámara. Permítelo en Ajustes o usa "Escribir código".')
                  : tr('No se pudo abrir la cámara. Usa "Escribir código".'), textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
              if (permiso && !kIsWeb) Padding(padding: const EdgeInsets.only(top: 12), child: FilledButton.icon(
                onPressed: abrirAjustesDeLaApp, icon: const Icon(Icons.settings), label: Text(tr('Ir a Ajustes'))))]))));
        }),
      IgnorePointer(child: Center(child: Container(width: 240, height: 240, decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(16))))),
      if (busy) const ColoredBox(color: Colors.black38, child: Center(child: CircularProgressIndicator()))])),
    Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr(widget.instruccion), textAlign: TextAlign.center, style: Theme.of(c).textTheme.bodyLarge),
      if (error != null) Semantics(liveRegion: true, child: Padding(padding: const EdgeInsets.only(top: 8),
        child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: C.error, fontWeight: FontWeight.w600)))),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: busy ? null : _manual, icon: const Icon(Icons.keyboard), label: Text(tr('Escribir código')))]))]);
}

/// Diálogo para escribir el código; es dueño de su controlador (se libera tras la animación de cierre).
class _CodigoDialog extends StatefulWidget { const _CodigoDialog();
  @override State<_CodigoDialog> createState() => _CodigoDialogState(); }

class _CodigoDialogState extends State<_CodigoDialog> {
  final _ctl = TextEditingController();
  @override
  void dispose() { _ctl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) => DialogoAdaptable(
    titulo: Text(tr('Código del paciente')),
    contenido: TextField(controller: _ctl, autofocus: true, decoration: InputDecoration(labelText: tr('Código que aparece bajo el QR')),
      onSubmitted: (v) => Navigator.pop(c, v)),
    acciones: [TextButton(style: estiloBotonDialogo, onPressed: () => Navigator.pop(c), child: Text(tr('Cancelar'))),
      FilledButton(style: estiloBotonDialogo, onPressed: () => Navigator.pop(c, _ctl.text), child: Text(tr('Continuar')))]);
}
