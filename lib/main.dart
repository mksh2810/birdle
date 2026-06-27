import 'dart:math';
import 'package:flutter/material.dart';
import 'ad_service.dart';
import 'game.dart';
import 'dictionary_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AdService.instance.initialize();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Birdle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F4EB), // Cream background matching the logo
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6CA372), // Sage Green
          primary: const Color(0xFF6CA372),
          secondary: const Color(0xFFF2AF37), // Mustard Yellow
          surface: const Color(0xFFF7F4EB),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F4EB),
          foregroundColor: Color(0xFF4E5156),
          elevation: 0,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Image.asset(
            'assets/logo_appbar.png',
            height: 45,
            fit: BoxFit.contain,
          ),
          centerTitle: true,
        ),
        body: const SafeArea(child: GamePage()),
      ),
    );
  }
}

class Tile extends StatelessWidget {
  const Tile(this.letter, this.hitType, {super.key, this.index = 0});

  final String letter;
  final HitType hitType;
  final int index;

  @override
  Widget build(BuildContext context) {
    final fillColor = switch (hitType) {
      HitType.hit => const Color(0xFF6CA372), // Sage Green from logo
      HitType.partial => const Color(0xFFF2AF37), // Mustard Yellow from logo
      HitType.miss => const Color(0xFF56595F), // Slate Grey from logo
      HitType.none => const Color(0xFFF9F7F1), // Cream background for unused
    };

    final textColor = switch (hitType) {
      HitType.none => const Color(0xFF4E5156), // Dark Grey text
      _ => Colors.white,
    };

    return AnimatedContainer(
      key: ValueKey('tile-$index-${hitType.name}'),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF4E5156), // Outline from logo
          width: 2.5,
        ),
        borderRadius: BorderRadius.circular(14),
        color: fillColor,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Center(
          key: ValueKey('${letter.toUpperCase()}-${hitType.name}-$index'),
          child: Text(
            letter.toUpperCase(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final Game _game = Game();
  String? _statusMessage;
  bool _showAnswer = false;
  bool _isLoadingDefinition = true;
  WordDefinition? _currentDefinition;
  int _shakeTrigger = 0;

  @override
  void initState() {
    super.initState();
    _loadDefinition();
  }

  Future<void> _loadDefinition() async {
    setState(() {
      _isLoadingDefinition = true;
    });

    await _game.loadDefinition();

    if (mounted) {
      setState(() {
        _currentDefinition = _game.definition;
        _isLoadingDefinition = false;
      });
    }
  }

  void _setStatus(String message) {
    setState(() {
      _statusMessage = message;
    });
  }

  void _submitGuess(String rawGuess) {
    final guess = rawGuess.trim().toLowerCase();

    if (_game.isGameOver || _showAnswer) return;

    if (guess.length != 5) {
      setState(() {
        _shakeTrigger++;
      });
      _setStatus('Enter a 5-letter word.');
      return;
    }

    if (!_game.isLegalGuess(guess)) {
      setState(() {
        _shakeTrigger++;
      });
      _setStatus('That word is not in the list.');
      return;
    }

    setState(() {
      _game.guess(guess);
      if (_game.didWin) {
        _statusMessage = '🎉 You got it!';
      } else if (_game.didLose) {
        _showAnswer = true;
        _statusMessage =
            'Out of guesses. The answer was ${_game.hiddenWord.toString().toUpperCase()}.';
      } else {
        _statusMessage = 'Keep going! ${_game.guessesRemaining} guesses left.';
      }
    });
  }

  void _showHint() {
    if (_game.isGameOver || _showAnswer) return;

    if (_game.freeHintsRemaining > 0) {
      setState(() {
        _game.useFreeHint();
        final index = _game.revealRandomLetter();
        if (index != -1) {
          final char = _game.hiddenWord[index].char.toUpperCase();
          final ordinal = _getOrdinal(index + 1);
          _setStatus('Free Hint (${_game.freeHintsUsed}/2 used): The $ordinal letter is "$char".');
        } else {
          _setStatus('All letters are already revealed!');
        }
      });
    } else {
      _showWatchAdDialog();
    }
  }

  void _showWatchAdDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.video_library, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Get Extra Hint'),
          ],
        ),
        content: const Text(
          'You have used all of your free hints. Would you like to watch a short ad to reveal a letter of the word?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _watchAdForHint();
            },
            child: const Text('Watch Ad'),
          ),
        ],
      ),
    );
  }

  void _watchAdForHint() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    AdService.instance.showRewardedAd(
      onRewardEarned: () {
        Navigator.of(context).pop(); // dismiss loading spinner
        setState(() {
          final index = _game.revealRandomLetter();
          if (index != -1) {
            final char = _game.hiddenWord[index].char.toUpperCase();
            final ordinal = _getOrdinal(index + 1);
            _setStatus('Ad Reward: The $ordinal letter is "$char".');
          } else {
            _setStatus('All letters are already revealed!');
          }
        });
      },
      onAdFailed: () {
        Navigator.of(context).pop(); // dismiss loading spinner
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load ad. Please try again later.'),
          ),
        );
      },
    );
  }

  String _getOrdinal(int number) {
    if (number == 1) return '1st';
    if (number == 2) return '2nd';
    if (number == 3) return '3rd';
    return '${number}th';
  }

  void _giveUp() {
    if (_game.isGameOver || _showAnswer) return;
    setState(() {
      _showAnswer = true;
      _statusMessage =
          'The answer was ${_game.hiddenWord.toString().toUpperCase()}.';
    });
  }

  void _resetGame() {
    setState(() {
      _game.resetGame();
      _showAnswer = false;
      _statusMessage = null;
      _currentDefinition = null;
    });
    _loadDefinition();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [


                // ── Spell-Bee Clue Card ──
                _buildClueCard(theme, colorScheme),
                const SizedBox(height: 12),

                // ── Status bar ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Guesses left: ${_game.guessesRemaining}',
                      style: theme.textTheme.titleMedium,
                    ),
                    if (_currentDefinition?.partOfSpeech != null)
                      Chip(
                        label: Text(
                          _currentDefinition!.partOfSpeech!,
                          style: TextStyle(
                            color: colorScheme.onSecondaryContainer,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: colorScheme.secondaryContainer,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_statusMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _game.didWin
                          ? Colors.green.shade50
                          : _game.didLose || _showAnswer
                              ? Colors.red.shade50
                              : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusMessage!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // ── Guess grid wrapped in ShakeWidget ──
                ShakeWidget(
                  shakeTrigger: _shakeTrigger,
                  child: Column(
                    children: [
                      for (var rowIndex = 0; rowIndex < _game.guesses.length; rowIndex++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (
                                var colIndex = 0;
                                colIndex < _game.guesses[rowIndex].length;
                                colIndex++
                              )
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                  child: Tile(
                                    _game.guesses[rowIndex][colIndex].char,
                                    _game.guesses[rowIndex][colIndex].type,
                                    index: rowIndex * 5 + colIndex,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Input ──
                GuessInput(
                  enabled: !(_game.isGameOver || _showAnswer),
                  onSubmitGuess: _submitGuess,
                ),
                const SizedBox(height: 8),

                // ── Action buttons ──
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.lightbulb_outline),
                        label: Text('Hint (${_game.freeHintsRemaining}/2 left)'),
                        onPressed: _game.isGameOver || _showAnswer
                            ? null
                            : _showHint,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('Give up'),
                        onPressed: _game.isGameOver || _showAnswer ? null : _giveUp,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Answer reveal ──
                if (_showAnswer || _game.isGameOver)
                  Text(
                    'Answer: ${_game.hiddenWord.toString().toUpperCase()}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 8),

                // ── New game button ──
                TextButton.icon(
                  onPressed: _resetGame,
                  icon: const Icon(Icons.refresh),
                  label: const Text('New game'),
                ),
              ],
            ),
          ),
        ),
        // Confetti Win Overlay
        Positioned.fill(
          child: IgnorePointer(
            child: ConfettiWidget(isActive: _game.didWin),
          ),
        ),
      ],
    );
  }

  /// Builds the spell-bee style clue card showing definition and example.
  Widget _buildClueCard(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoadingDefinition) {
      return Card(
        elevation: 0,
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(height: 12),
              Text('Loading clue...'),
            ],
          ),
        ),
      );
    }

    if (_currentDefinition == null) {
      return const SizedBox.shrink();
    }

    final def = _currentDefinition!;
    final firstLetter = _game.hiddenWord[0].char.toUpperCase();
    final lastLetter = _game.hiddenWord[_game.hiddenWord.length - 1].char.toUpperCase();
    final pos = def.partOfSpeech != null ? def.partOfSpeech!.toUpperCase() : 'UNKNOWN';

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Spell-Bee Clues (Automatic)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            // Clue 1: POS & length
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📏 ',
                  style: theme.textTheme.bodyMedium,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Word Info',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'This word is a $pos. It has 5 letters. It starts with "$firstLetter" and ends with "$lastLetter".',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Clue 2: Definition
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📖 ',
                  style: theme.textTheme.bodyMedium,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Definition',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        def.definition,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (def.example != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💬 ',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Example Sentence',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '"${def.example}"',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            // Revealed Letter Clues (both free and ad-rewarded)
            if (_game.revealedLetterIndices.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Revealed Letters',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_game.revealedLetterIndices.length, (i) {
                  final index = _game.revealedLetterIndices[i];
                  final char = _game.hiddenWord[index].char.toUpperCase();
                  final ordinal = _getOrdinal(index + 1);
                  final isFree = i < 2; // The first two hints are free
                  return Chip(
                    avatar: Icon(
                      isFree ? Icons.check_circle_outline : Icons.check_circle,
                      color: isFree ? colorScheme.primary : Colors.green.shade700,
                      size: 16,
                    ),
                    label: Text(
                      '${isFree ? "Free Hint" : "Ad Reward"}: $ordinal letter is "$char"',
                      style: TextStyle(
                        color: isFree ? colorScheme.onPrimaryContainer : Colors.green.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: isFree ? colorScheme.primaryContainer.withValues(alpha: 0.5) : Colors.green.shade50,
                    side: BorderSide(color: isFree ? colorScheme.primary.withValues(alpha: 0.3) : Colors.green.shade200),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class GuessInput extends StatefulWidget {
  const GuessInput({
    super.key,
    required this.onSubmitGuess,
    required this.enabled,
  });

  final void Function(String) onSubmitGuess;
  final bool enabled;

  @override
  State<GuessInput> createState() => _GuessInputState();
}

class _GuessInputState extends State<GuessInput> {
  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  void _onSubmit() {
    final guess = _textEditingController.text.trim();
    if (guess.isEmpty) return;
    widget.onSubmitGuess(guess);
    _textEditingController.clear();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            enabled: widget.enabled,
            maxLength: 5,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              hintText: 'Guess the 5-letter word',
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(35)),
              ),
            ),
            controller: _textEditingController,
            focusNode: _focusNode,
            autofocus: true,
            onSubmitted: (_) => _onSubmit(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_circle_up),
          onPressed: widget.enabled ? _onSubmit : null,
        ),
      ],
    );
  }
}

// ── Visual Effect Widgets ──

/// A widget that shakes its child horizontally when [shakeTrigger] changes.
class ShakeWidget extends StatefulWidget {
  const ShakeWidget({
    super.key,
    required this.child,
    required this.shakeTrigger,
  });

  final Widget child;
  final int shakeTrigger;

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 500),
    vsync: this,
  );

  @override
  void didUpdateWidget(covariant ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeTrigger != oldWidget.shakeTrigger) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final double sineValue = sin(_controller.value * 4 * pi);
        return Transform.translate(
          offset: Offset(sineValue * 8 * (1 - _controller.value), 0),
          child: child,
        );
      },
    );
  }
}

/// Particle model for the win confetti effect.
class ConfettiParticle {
  ConfettiParticle({
    required this.color,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
  });

  final Color color;
  double x;
  double y;
  double vx;
  double vy;
  final double size;
  double rotation;
  final double rotationSpeed;
}

/// A widget that displays a win confetti particle animation.
class ConfettiWidget extends StatefulWidget {
  const ConfettiWidget({super.key, required this.isActive});

  final bool isActive;

  @override
  State<ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<ConfettiWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  final List<ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      _updateParticles();
    });
  }

  @override
  void didUpdateWidget(covariant ConfettiWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _spawnParticles();
      _controller.repeat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _particles.clear();
    }
  }

  void _spawnParticles() {
    _particles.clear();
    final colors = [
      const Color(0xFF6CA372), // Sage Green
      const Color(0xFFF2AF37), // Mustard Yellow
      const Color(0xFF56595F), // Slate Grey
      const Color(0xFFEEAA30), // Lighter Yellow
      Colors.red.shade400,
      Colors.blue.shade400,
    ];

    for (var i = 0; i < 100; i++) {
      _particles.add(
        ConfettiParticle(
          color: colors[_random.nextInt(colors.length)],
          x: 0.5,
          y: 0.2,
          vx: (_random.nextDouble() - 0.5) * 0.08,
          vy: -_random.nextDouble() * 0.1 - 0.05,
          size: _random.nextDouble() * 8 + 6,
          rotation: _random.nextDouble() * 2 * pi,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.2,
        ),
      );
    }
  }

  void _updateParticles() {
    if (!mounted) return;
    setState(() {
      for (final p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.vy += 0.005; // gravity
        p.rotation += p.rotationSpeed;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();

    return CustomPaint(
      painter: _ConfettiPainter(_particles),
      child: Container(),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles);

  final List<ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final px = p.x * size.width;
      final py = p.y * size.height;

      if (py > size.height || px < 0 || px > size.width) continue;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation);
      paint.color = p.color;
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
