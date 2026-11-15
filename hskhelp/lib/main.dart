import 'package:flutter/material.dart';

import 'data/word_repository.dart';
import 'l10n.dart';
import 'models/word.dart';
import 'screens/home_screen.dart';
import 'services/stats_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final stats = await StatsService.load();
    final words = await WordRepository().load();
    runApp(HskHelpApp(words: words, stats: stats));
  } catch (error) {
    runApp(_ErrorApp(error: error));
  }
}

class HskHelpApp extends StatefulWidget {
  const HskHelpApp({
    super.key,
    required this.words,
    required this.stats,
  });

  final List<Word> words;
  final StatsService stats;

  @override
  State<HskHelpApp> createState() => _HskHelpAppState();
}

class _HskHelpAppState extends State<HskHelpApp> {
  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    // Un réglage change -> palette et langue du MaterialApp sont reconstruits,
    // donc toute l'interface suit immédiatement.
    return ListenableBuilder(
      listenable: stats,
      builder: (context, _) {
        return MaterialApp(
          title: 'HSK Help',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(stats.palette),
          // L'AppScope couvre le navigateur : les écrans poussés (quiz,
          // réglages, bilan) y trouvent eux aussi la langue courante.
          builder: (context, child) => AppScope(
            strings: Strings(stats.lang),
            child: child ?? const SizedBox.shrink(),
          ),
          home: HomeScreen(words: widget.words, stats: stats),
        );
      },
    );
  }
}

class _ErrorApp extends StatelessWidget {
  const _ErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final s = Strings(AppLang.fr);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(kPalettes.first),
      home: Scaffold(
        body: Container(
          decoration: appBackground(),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 48, color: AppColors.accent),
                  const SizedBox(height: 16),
                  Text(
                    s.loadError,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
