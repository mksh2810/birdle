/// Game logic and supporting types for Birdle,
/// a five-letter word-guessing game with spell-bee style clues.
///
/// Defines the [Game] state machine and the
/// [Word], [Letter], and [HitType] data model used to
/// represent guesses and their evaluation against a hidden word.
library;

import 'dart:collection';
import 'dart:math';
import 'words.dart';
import 'dictionary_service.dart';

/// The result of evaluating a [Letter] of a guess against the hidden word.
enum HitType {
  /// The letter hasn't yet been evaluated.
  none,

  /// The letter matches the hidden word's letter at the same position.
  hit,

  /// The letter is in the hidden word, but at a different position.
  partial,

  /// The letter doesn't appear in the hidden word.
  miss,
}

/// A single character paired with its [HitType] against the hidden word.
typedef Letter = ({String char, HitType type});

/// Words excluded from being chosen as answers because they are primarily
/// known as proper nouns, place names, or have confusing/obscure definitions.
/// They remain valid as guesses.
const Set<String> _excludedAnswerWords = {
  // Countries & territories
  'japan', 'china', 'india', 'italy', 'egypt', 'chile', 'niger', 'tonga',
  'yemen', 'benin', 'gabon', 'ghana', 'haiti', 'kenya', 'libya', 'malta',
  'nauru', 'nepal', 'palau', 'qatar', 'samoa', 'spain', 'sudan', 'syria',
  'wales', 'congo', 'korea', 'burma', 'perth', 'aruba',
  'guam',
  // Cities & places
  'paris', 'delhi', 'miami', 'tokyo', 'cairo', 'kabul', 'lagos', 'lyons',
  'minsk', 'osaka', 'quito', 'rabat', 'boise', 'omaha', 'tulsa', 'dover',
  'selma', 'wuhan', 'texas', 'maine', 'idaho', 'essex', 'tibet', 'rhode',
  // People names
  'aaron', 'abram', 'agnes', 'alice', 'andre', 'angel', 'annie', 'barry',
  'betty', 'billy', 'blake', 'bobby', 'boris', 'brett', 'brian', 'bruce',
  'candy', 'carol', 'casey', 'cecil', 'chloe', 'chris', 'cindy', 'clara',
  'clare', 'cliff', 'clint', 'clive', 'clyde', 'corey', 'craig', 'cyril',
  'daisy', 'danny', 'daryl', 'david', 'davis', 'derek', 'diana', 'diego',
  'dolly', 'donna', 'donny', 'doris', 'duane', 'dylan', 'eddie', 'edgar',
  'edith', 'elena', 'eliza', 'ellen', 'elmer', 'elton', 'elvis', 'emily',
  'enoch', 'erica', 'ernie', 'errol', 'ethel', 'ethan', 'euler', 'faith',
  'fanny', 'felix', 'flora', 'floyd', 'flynn', 'frank', 'garth', 'gavin',
  'geoff', 'giles', 'glenn', 'grace', 'grant', 'gregg', 'gupta', 'harry',
  'hazel', 'heath', 'heidi', 'helen', 'henri', 'henry', 'homer', 'irene',
  'isaac', 'ivory', 'jacky', 'jacob', 'james', 'jamie', 'jason', 'jayne',
  'jenny', 'jerry', 'jesse', 'jimmy', 'jodie', 'jones', 'josie', 'joyce',
  'judas', 'jules', 'julia', 'julie', 'karen', 'kathy', 'keith', 'kelly',
  'kenny', 'kerry', 'kevin', 'lance', 'larry', 'laura', 'leigh', 'lenny',
  'leroy', 'lewis', 'libby', 'linda', 'lloyd', 'logan', 'lorna', 'louis',
  'lucas', 'lucia', 'lydia', 'mabel', 'mandy', 'marco', 'maria', 'mario',
  'mason', 'maude', 'mavis', 'meyer', 'mikey', 'miles', 'molly', 'monte',
  'monty', 'moore', 'moses', 'nancy', 'naomi', 'nicky', 'nigel', 'norma',
  'ollie', 'oscar', 'paddy', 'patsy', 'patty', 'paula', 'pearl', 'penny',
  'percy', 'perry', 'peter', 'petra', 'polly', 'putin', 'ralph', 'ramon',
  'randy', 'raoul', 'renee', 'rider', 'riley', 'robin', 'rocky', 'roger',
  'roman', 'romeo', 'rosie', 'rowan', 'rufus', 'sadie', 'sally', 'sandy',
  'sarah', 'scott', 'shaun', 'simon', 'stacy', 'steve', 'susan', 'tammy',
  'tanya', 'terry', 'timmy', 'tommy', 'tracy', 'trudy', 'tyler', 'venus',
  'vicky', 'viola', 'waldo', 'wally', 'wanda', 'wayne', 'wendy', 'willy',
  'wyatt', 'beryl', 'klein', 'plato', 'sonya', 'dante', 'orion', 'titan',
  // Abbreviations & jargon
  'abstr', 'assoc', 'comms', 'admin', 'debit',
  // Obscure/archaic words unlikely to be guessable
  'knave', 'liege', 'saith', 'thane', 'varlet',
};

/// The filtered list of answer words, excluding proper nouns and confusing words.
final List<String> filteredAnswerWords = answerWords
    .where((w) => !_excludedAnswerWords.contains(w))
    .toList(growable: false);

/// Game state of a single round of Birdle,
/// a five-letter word-guessing game with spell-bee style clues.
///
/// Each round picks a hidden word, fetches its definition and example
/// from the Free Dictionary API, and presents them as clues.
/// The player guesses the word based on those clues.
///
/// Clients drive each round by calling [guess] to submit an attempt and
/// [resetGame] to start over.
class Game {
  /// The default maximum number of guesses allowed in a [Game].
  static const int defaultMaxGuesses = 5;

  /// Creates a new game with [maxGuesses] guesses allowed.
  ///
  /// If [seed] is provided, the hidden word is
  /// chosen deterministically from [answerWords],
  /// otherwise it is selected at random.
  Game({this.maxGuesses = defaultMaxGuesses, this.seed})
    : _wordToGuess = _generateInitialWord(seed),
      _guesses = List<Word>.filled(maxGuesses, Word.empty());

  /// The maximum number of guesses allowed in this game.
  final int maxGuesses;

  /// The seed used to choose the hidden word,
  /// or `null` if it was selected at random.
  final int? seed;

  /// The current hidden word, exposed publicly through [hiddenWord].
  Word _wordToGuess;

  /// Backing storage for [guesses].
  ///
  /// Holds every guess slot in order,
  /// with unfilled slots represented by empty [Word]s.
  List<Word> _guesses;

  /// The current word definition fetched from the dictionary API.
  WordDefinition? _definition;

  /// Whether the definition is currently being fetched.
  bool _isLoadingDefinition = false;

  /// The word the player is trying to guess.
  Word get hiddenWord => _wordToGuess;

  /// Number of free hints used by the player in the current round.
  int _freeHintsUsed = 0;

  /// Indices of letters in the hidden word that have been revealed by ads.
  final List<int> _revealedLetterIndices = [];

  /// Returns the number of free hints remaining.
  int get freeHintsRemaining => max(0, 2 - _freeHintsUsed);

  /// Returns the number of free hints used.
  int get freeHintsUsed => _freeHintsUsed;

  /// Returns the list of indices of letters revealed by ads.
  List<int> get revealedLetterIndices => UnmodifiableListView(_revealedLetterIndices);

  /// Increments the free hint usage if any are remaining.
  void useFreeHint() {
    if (_freeHintsUsed < 2) {
      _freeHintsUsed++;
    }
  }

  /// Reveals a random unrevealed letter of the hidden word.
  /// Returns the index of the revealed letter, or -1 if all are revealed.
  int revealRandomLetter() {
    final wordLength = _wordToGuess.length;
    final unrevealedIndices = <int>[];
    for (var i = 0; i < wordLength; i++) {
      if (!_revealedLetterIndices.contains(i)) {
        unrevealedIndices.add(i);
      }
    }

    if (unrevealedIndices.isEmpty) {
      return -1;
    }

    final random = Random();
    final indexToReveal = unrevealedIndices[random.nextInt(unrevealedIndices.length)];
    _revealedLetterIndices.add(indexToReveal);
    return indexToReveal;
  }

  /// The current definition and example for the hidden word.
  WordDefinition? get definition => _definition;

  /// Whether a definition fetch is in progress.
  bool get isLoadingDefinition => _isLoadingDefinition;

  /// An unmodifiable view of every guess slot, including those still empty.
  UnmodifiableListView<Word> get guesses => UnmodifiableListView(_guesses);

  /// The most recently submitted guess,
  /// or an empty [Word] if no guesses have been made.
  Word get previousGuess {
    final index = _guesses.lastIndexWhere((word) => word.isNotEmpty);
    return index == -1 ? Word.empty() : _guesses[index];
  }

  /// The index of the next empty guess slot, or `-1` if every slot is full.
  int get activeIndex => _guesses.indexWhere((word) => word.isEmpty);

  /// The number of guesses still available to the player.
  int get guessesRemaining {
    if (activeIndex == -1) return 0;
    return maxGuesses - activeIndex;
  }

  /// Whether the most recent guess matches the hidden word.
  bool get didWin {
    if (_guesses.first.isEmpty) return false;

    for (final letter in previousGuess) {
      if (letter.type != HitType.hit) return false;
    }

    return true;
  }

  /// Whether all allowed guesses have been used without winning.
  bool get didLose => guessesRemaining == 0 && !didWin;

  /// Whether the round is already over.
  bool get isGameOver => didWin || didLose;

  /// Maximum number of times to re-pick a word if the definition
  /// looks like a proper noun or is unusable.
  static const int _maxRetries = 3;

  /// Fetches the definition for the current hidden word from the API.
  ///
  /// If the definition looks like a proper noun (mentions a country,
  /// person, or place), automatically picks a new word and retries
  /// up to [_maxRetries] times.
  Future<void> loadDefinition() async {
    _isLoadingDefinition = true;
    try {
      for (var attempt = 0; attempt < _maxRetries; attempt++) {
        final def = await DictionaryService.fetchDefinition(
          _wordToGuess.toString(),
        );

        // Check if the definition looks like a proper noun reference.
        if (!_looksLikeProperNounDef(def)) {
          _definition = def;
          return;
        }

        // Re-pick a different word and try again.
        _wordToGuess = _generateInitialWord(null);
        _guesses = List<Word>.filled(maxGuesses, Word.empty());
      }

      // After retries, accept whatever we get.
      _definition = await DictionaryService.fetchDefinition(
        _wordToGuess.toString(),
      );
    } catch (_) {
      _definition = WordDefinition.fallback(_wordToGuess.toString());
    } finally {
      _isLoadingDefinition = false;
    }
  }

  /// Heuristic: returns `true` if the definition mentions geographic,
  /// biographical, or proper-noun patterns that would confuse players.
  static bool _looksLikeProperNounDef(WordDefinition def) {
    final text = def.definition.toLowerCase();
    const patterns = [
      'a country', 'a city', 'a town', 'a state', 'a province',
      'a region', 'a continent', 'a river', 'a mountain',
      'a person', 'a name', 'first name', 'given name', 'surname',
      'capital of', 'republic of', 'kingdom of', 'island in',
      'located in', 'inhabitant of', 'native of',
    ];
    return patterns.any((p) => text.contains(p));
  }

  /// Picks a new hidden word and clears every submitted guess.
  void resetGame() {
    _wordToGuess = _generateInitialWord(seed);
    _guesses = List<Word>.filled(maxGuesses, Word.empty());
    _definition = null;
    _isLoadingDefinition = false;
    _freeHintsUsed = 0;
    _revealedLetterIndices.clear();
  }

  /// Evaluates [guess] against the hidden word,
  /// records the result in [guesses], and returns it.
  ///
  /// For finer control, use [isLegalGuess] to validate input or
  /// [matchGuessOnly] to evaluate without recording the result.
  Word guess(String guess) {
    final result = matchGuessOnly(guess);
    addGuessToList(result);
    return result;
  }

  /// Whether [guess] is a legal word to guess.
  ///
  /// UIs can call this method before [guess] to
  /// show players a message when they enter an invalid word.
  bool isLegalGuess(String guess) {
    if (guess.length != 5) return false;
    return Word.fromString(guess).isLegalGuess;
  }

  /// Returns a short clue for the hidden word.
  String getHint() {
    final word = hiddenWord.toString();
    if (_definition != null && _definition!.example != null) {
      return 'Example: ${_definition!.example}';
    }
    return 'Hint: the word starts with "${word[0].toUpperCase()}" and ends with "${word[word.length - 1].toUpperCase()}".';
  }

  /// Evaluates [guess] against the hidden word without advancing the game.
  Word matchGuessOnly(String guess) =>
      Word.fromString(guess).evaluateGuess(_wordToGuess);

  /// Stores [guess] in the next empty slot of [guesses].
  void addGuessToList(Word guess) {
    final guessIndex = activeIndex;
    if (guessIndex == -1) {
      throw StateError('No guesses remaining.');
    }

    _guesses[guessIndex] = guess;
  }

  /// Returns the starting hidden word for a new round.
  ///
  /// Picks a deterministic word from [answerWords] when [seed] is provided,
  /// or one at random otherwise.
  static Word _generateInitialWord(int? seed) =>
      seed == null ? Word.random() : Word.fromSeed(seed);
}

/// A five-letter word made up of [Letter]s, each tracking its [HitType].
class Word with IterableMixin<Letter> {
  /// Creates a word backed by the specified list of [Letter]s.
  Word(this._letters);

  /// Creates a word with five blank letters of [HitType.none].
  factory Word.empty() =>
      Word(List<Letter>.filled(5, (char: '', type: HitType.none)));

  /// Creates a [Word] from [guess].
  ///
  /// Each character is lowercased,
  /// every [Letter] starts as [HitType.none].
  factory Word.fromString(String guess) {
    if (guess.length != 5) {
      throw ArgumentError.value(
        guess,
        'guess',
        'Must be exactly 5 characters long.',
      );
    }

    final letters = guess
        .toLowerCase()
        .split('')
        .map((char) => (char: char, type: HitType.none))
        .toList();
    return Word(letters);
  }

  /// Creates a word chosen at random from [filteredAnswerWords].
  factory Word.random() {
    final random = Random();
    final nextWord = filteredAnswerWords[random.nextInt(filteredAnswerWords.length)];
    return Word.fromString(nextWord);
  }

  /// Creates a word chosen from [filteredAnswerWords] using [seed] as an index.
  factory Word.fromSeed(int seed) =>
      Word.fromString(filteredAnswerWords[seed % filteredAnswerWords.length]);

  /// An unmodifiable list of [Letter]s that make up this word.
  final List<Letter> _letters;

  @override
  Iterator<Letter> get iterator => _letters.iterator;

  /// Whether every [Letter] in this word has no character.
  @override
  bool get isEmpty => every((letter) => letter.char.isEmpty);

  @override
  int get length => _letters.length;

  /// The [Letter] at index [i] in word.
  Letter operator [](int i) => _letters[i];

  @override
  String toString() => _letters.map((letter) => letter.char).join().trim();

  /// Returns a multi-line string showing each [Letter] alongside its [HitType].
  ///
  /// Used to play the game from the command line.
  String toStringVerbose() => _letters
      .map((letter) => '${letter.char} - ${letter.type.name}')
      .join('\n');
}

/// Validation and guess-evaluation logic on [Word].
extension WordUtils on Word {
  /// Whether this word appears in [allValidGuesses].
  bool get isLegalGuess => allValidGuesses.contains(toString());

  /// Compares this [Word] against the specified [hiddenWord]
  /// and returns a new [Word] with the same letters,
  /// but where each [Letter] has new a [HitType] of
  /// [HitType.hit], [HitType.partial], or [HitType.miss].
  Word evaluateGuess(Word hiddenWord) {
    assert(isLegalGuess);

    final result = List<Letter>.filled(length, (char: '', type: HitType.none));
    // Counts hidden-word letters that can still be claimed as partial matches.
    final unmatchedHiddenLetterCounts = <String, int>{};

    // Reserve exact matches before scoring partial matches.
    for (var i = 0; i < length; i++) {
      final guessChar = this[i].char;
      final hiddenChar = hiddenWord[i].char;

      if (guessChar == hiddenChar) {
        result[i] = (char: guessChar, type: HitType.hit);
      } else {
        // Track non-hit hidden letters for the partial-match pass.
        final unmatchedCount = unmatchedHiddenLetterCounts[hiddenChar] ?? 0;
        unmatchedHiddenLetterCounts[hiddenChar] = unmatchedCount + 1;
      }
    }

    // Spend each remaining hidden letter only once for partial matches.
    for (var i = 0; i < length; i++) {
      if (result[i].type == HitType.hit) continue;

      final guessChar = this[i].char;
      final unmatchedCount = unmatchedHiddenLetterCounts[guessChar] ?? 0;
      final isPartial = unmatchedCount > 0;
      if (isPartial) {
        // Use one available hidden letter for this partial match.
        unmatchedHiddenLetterCounts[guessChar] = unmatchedCount - 1;
      }

      result[i] = (
        char: guessChar,
        type: isPartial ? HitType.partial : HitType.miss,
      );
    }

    return Word(result);
  }
}
