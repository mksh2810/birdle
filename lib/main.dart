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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.spellcheck, size: 28),
              SizedBox(width: 8),
              Text(
                'Birdle',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          centerTitle: false,
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
      HitType.hit => Colors.green.shade600,
      HitType.partial => Colors.amber.shade600,
      HitType.miss => Colors.grey.shade600,
      HitType.none => Colors.white,
    };

    return AnimatedContainer(
      key: ValueKey('tile-$index-${hitType.name}'),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: fillColor,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Center(
          key: ValueKey('${letter.toUpperCase()}-${hitType.name}-$index'),
          child: Text(
            letter.toUpperCase(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: hitType == HitType.none ? Colors.black87 : Colors.white,
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
      _setStatus('Enter a 5-letter word.');
      return;
    }

    if (!_game.isLegalGuess(guess)) {
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
        final step = _game.freeHintsUsed;
        if (step == 1) {
          _setStatus('Hint 1 unlocked: Word structure revealed.');
        } else if (step == 2) {
          _setStatus('Hint 2 unlocked: Dictionary definition revealed.');
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

    return SingleChildScrollView(
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

            // ── Guess grid ──
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

    // If 0 hints are used, show a card prompt to click the hint button.
    if (_game.freeHintsUsed == 0) {
      return Card(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: colorScheme.primary, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spelling Clues Locked',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap the "Hint" button below to unlock clues!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Otherwise, build the progressive clue card content.
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Spell-Bee Clues Unlocked',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Free Hints: ${_game.freeHintsUsed}/2',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary.withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            // Hint 1 Details (Always visible since _game.freeHintsUsed >= 1)
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
                        'Word Info (Hint 1)',
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

            // Hint 2 Details (Visible when _game.freeHintsUsed >= 2)
            if (_game.freeHintsUsed >= 2) ...[
              const SizedBox(height: 16),
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
                          'Definition (Hint 2)',
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
            ],

            // Ad Hints (Visible when ad letters are revealed)
            if (_game.revealedLetterIndices.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Icon(Icons.video_library, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Revealed Letters (Ad Rewards)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _game.revealedLetterIndices.map((index) {
                  final char = _game.hiddenWord[index].char.toUpperCase();
                  final ordinal = _getOrdinal(index + 1);
                  return Chip(
                    avatar: Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                    label: Text(
                      '$ordinal letter is "$char"',
                      style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.green.shade50,
                    side: BorderSide(color: Colors.green.shade200),
                  );
                }).toList(),
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
