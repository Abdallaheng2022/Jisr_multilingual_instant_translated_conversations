import 'package:flutter/material.dart';

import '../services/ondevice/ondevice_voice.dart';

/// شاشة تنزيل نماذج الجهاز (الطبقة المجانية).
///
/// نزّل مسبقاً بدل المفاجأة أثناء أول ترجمة: أول استخدام مجاني يحتاج
/// Whisper (~75MB) + صوت Piper لكل لغة (~60–90MB).
///
/// الاستخدام:
///   await Navigator.push(context, MaterialPageRoute(
///     builder: (_) => ModelDownloadScreen(
///       onDevice: onDevice,
///       langs: {appState.sourceLang.code, appState.targetLang.code},
///     ),
///   ));
class ModelDownloadScreen extends StatefulWidget {
  const ModelDownloadScreen({
    super.key,
    required this.onDevice,
    required this.langs,
  });

  final OnDeviceVoice onDevice;
  final Set<String> langs;

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen> {
  double? _fraction;
  String _label = '';
  int _index = 0;
  int _total = 0;
  bool _running = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final ready = await widget.onDevice.isReadyFor(widget.langs);
    if (mounted && ready) setState(() => _done = true);
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      await widget.onDevice.prefetch(
        widget.langs,
        onProgress: (label, fraction, i, total) {
          if (!mounted) return;
          setState(() {
            _label = label;
            _fraction = fraction;
            _index = i;
            _total = total;
          });
        },
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = _fraction == null ? null : (_fraction! * 100).toStringAsFixed(0);

    return Scaffold(
      appBar: AppBar(title: const Text('تجهيز الأصوات')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              _done ? Icons.check_circle_outline : Icons.download_outlined,
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              _done
                  ? 'كل شيء جاهز — يعمل بلا إنترنت الآن'
                  : 'يحتاج التطبيق تنزيل ملفات الصوت مرة واحدة\n'
                      'لتعمل الترجمة على جهازك بلا إنترنت.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),

            if (_running) ...[
              LinearProgressIndicator(value: _fraction),
              const SizedBox(height: 12),
              Text(
                _total > 0
                    ? 'ملف $_index من $_total${pct != null ? ' — $pct٪' : ''}'
                    : 'جارٍ التنزيل…',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                'تعذّر التنزيل: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],

            const SizedBox(height: 32),
            if (_done)
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('متابعة'),
              )
            else
              FilledButton(
                onPressed: _running ? null : _start,
                child: Text(_error != null ? 'إعادة المحاولة' : 'تنزيل الآن'),
              ),
            const SizedBox(height: 12),
            if (!_done)
              TextButton(
                onPressed: _running ? null : () => Navigator.of(context).maybePop(),
                child: const Text('لاحقاً'),
              ),
          ],
        ),
      ),
    );
  }
}
