# Birdle 🐦

An enhanced, spell-bee style word-guessing game built with Flutter. Inspired by Wordle, Birdle challenges players to guess a hidden 5-letter English word using dictionary definitions, usage examples, and traditional color-coded tile feedback.

## Features

- **Massive Word Pool**: Over 21,000+ valid guess words and 2,600+ hand-picked common answer words, ensuring a fresh challenge every time.
- **Spell-Bee Style Clues**: Every round fetches live definitions and usage examples from the [Free Dictionary API](https://dictionaryapi.dev/).
- **Smart Filtering**: Proper nouns, country names, abbreviations, and extremely obscure words are dynamically filtered out of answer choices to keep gameplay fun and fair.
- **Offline Fallback**: If the API is unreachable or rate-limited, the game automatically switches to character-hint fallbacks (e.g., "starts with A and ends with E").
- **Premium UI/UX**: Built with Flutter and Material 3, featuring sleek card components, smooth micro-animations, and responsive tile feedback.

## How to Play

1. **Read the Clues**: At the start of a round, check the **Spell-Bee Clue** card at the top. It provides the **Definition** and an **Example** sentence with the target word hidden under blanks (`_____`).
2. **Submit a Guess**: Enter a valid 5-letter word and submit.
3. **Analyze the Tiles**:
   - 🟩 **Green**: The letter is in the correct position.
   - 🟨 **Amber**: The letter is in the word but in the wrong position.
   - ⬛ **Grey**: The letter is not in the word.
4. **Win or Try Again**: You have 5 attempts to guess the correct word. You can also request an extra hint or restart with a "New Game" anytime.

## Technical Details

- **Language**: Dart / Flutter
- **State Machine**: Custom Game State in `lib/game.dart`
- **Network Calls**: `http` package integration with `https://api.dictionaryapi.dev`
- **Word Source**: Local cache generated from the Datamuse API

## Getting Started

1. Clone the repository.
2. Ensure you have the Flutter SDK installed.
3. Run the project:
   ```bash
   flutter pub get
   flutter run
   ```
