import 'package:birdle/game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hint exposes the first letter of the hidden word', () {
    final game = Game(seed: 0);
    final hint = game.getHint();

    expect(hint, contains(game.hiddenWord[0].char));
  });

  test('guessing the secret word marks the game as won', () {
    final game = Game(seed: 0);
    final winningGuess = game.hiddenWord.toString();

    game.guess(winningGuess);

    expect(game.didWin, isTrue);
  });
}
