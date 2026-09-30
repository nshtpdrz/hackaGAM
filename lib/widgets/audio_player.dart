import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../core/state.dart';
import '../core/tr.dart';

/// Reproductor de un message_key: audio del catálogo (Hñähñu) o voz sintetizada (es/en). Con detener.
class MsgAudioPlayer extends ConsumerStatefulWidget {
  final String k; const MsgAudioPlayer(this.k, {super.key});
  @override ConsumerState<MsgAudioPlayer> createState() => _MsgAudioState();
}
class _MsgAudioState extends ConsumerState<MsgAudioPlayer> {
  final _p = AudioPlayer(); final _tts = FlutterTts(); bool playing = false;
  @override
  void initState() {
    super.initState();
    _p.onPlayerComplete.listen((_) { if (mounted) setState(() => playing = false); });
    _tts.setCompletionHandler(() { if (mounted) setState(() => playing = false); });
  }
  @override
  void dispose() { _p.dispose(); _tts.stop(); super.dispose(); }

  Future<void> _toggle() async {
    if (playing) { await _p.stop(); await _tts.stop(); setState(() => playing = false); return; }
    final m = ref.read(trProvider)(widget.k); final lang = ref.read(prefsProvider).lang;
    setState(() => playing = true);
    if (m.audioUrl != null) { await _p.play(UrlSource(m.audioUrl!)); return; }
    await _tts.setLanguage(lang == 'en' ? 'en-US' : 'es-MX'); await _tts.speak(m.text);
  }
  @override
  Widget build(BuildContext c) => Semantics(button: true, label: playing ? tr('Detener audio') : tr('Escuchar indicaciones'), excludeSemantics: true,
    child: FilledButton.tonalIcon(onPressed: _toggle, icon: Icon(playing ? Icons.stop_circle_outlined : Icons.volume_up_rounded),
      label: Text(playing ? tr('Detener') : tr('Escuchar indicaciones'), style: TextStyle(color: Colors.white))));
}
