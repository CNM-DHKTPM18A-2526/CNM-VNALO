import 'package:vnalo_mobile/features/ai_assistant/utils/ai_command_routing.dart';
import 'package:vnalo_mobile/models/user_model.dart';

class AiActionTargetMatcher {
  const AiActionTargetMatcher._();

  static List<User> findUsersByName(Iterable<User> users, String name) {
    final normalized = AiCommandRouting.normalizeSearchText(name);
    if (normalized.isEmpty) return const <User>[];

    final exactById = <String, User>{};
    final scoredById = <String, ({User user, int score})>{};

    Iterable<String> labelsFor(User user) sync* {
      yield user.displayName;
      if (user.phone?.trim().isNotEmpty == true) yield user.phone!.trim();
      if (user.email?.trim().isNotEmpty == true) yield user.email!.trim();
    }

    for (final user in users) {
      var bestScore = -1;
      for (final label in labelsFor(user)) {
        final score = AiCommandRouting.computeNameMatchScore(label, normalized);
        if (score > bestScore) {
          bestScore = score;
        }
      }

      if (bestScore < 0) {
        continue;
      }
      if (bestScore >= 1000) {
        exactById[user.id] = user;
        continue;
      }

      final existing = scoredById[user.id];
      if (existing == null || bestScore > existing.score) {
        scoredById[user.id] = (user: user, score: bestScore);
      }
    }

    if (exactById.isNotEmpty) {
      return exactById.values.toList(growable: false);
    }

    final scored = scoredById.values.toList(growable: false)
      ..sort((a, b) {
        final scoreCompare = b.score.compareTo(a.score);
        if (scoreCompare != 0) {
          return scoreCompare;
        }
        return a.user.displayName.compareTo(b.user.displayName);
      });

    return scored.map((entry) => entry.user).toList(growable: false);
  }
}
