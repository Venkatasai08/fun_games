// lib/draftclash/services/deepseek_service.dart
//
// Generates character cards using Groq (free tier).
// Images: Jikan (MyAnimeList) or Wikipedia → raw source URL stored for preview.
// Cloudinary upload happens ONLY when the admin clicks Save.
//
// Free limits: 14,400 requests/day · 30 RPM · no credit card needed.
// Get your free key at: https://console.groq.com/keys
//
// Run with: --dart-define=GROQ_API_KEY=gsk_...
//
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/draft_card.dart';
import '../models/draft_franchise.dart';
import '../models/franchise_category.dart';

/// A lightweight holder for AI-generated character data before it's saved.
class GeneratedCharacter {
  final String name;
  final String description;
  double level;      // 1.0–10.0, supports decimals e.g. 7.5
  bool   selected;

  /// Direct URL from Jikan / Wikipedia — used for preview in the list.
  /// Never stored in Firestore.
  String rawImageUrl;

  /// Cloudinary CDN URL — set during Save, then stored in Firestore.
  /// Empty until the admin presses Save.
  String imageUrl;

  GeneratedCharacter({
    required this.name,
    required this.description,
    required this.level,
    this.selected    = true,
    this.rawImageUrl = '',
    this.imageUrl    = '',
  });
}

class DeepSeekService {
  static const _apiKey  = String.fromEnvironment('GROQ_API_KEY');
  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model   = 'llama-3.3-70b-versatile';

  // Jikan rate limit: 3 req/s — 400 ms delay keeps us safe
  static const _jikanDelay = Duration(milliseconds: 450);

  // ── Main generation call ─────────────────────────────────────────────────
  //
  // FLOW:
  //   Step 1 — Groq:  generate names + descriptions + levels
  //   Step 2 — Images: fetch raw source URL (Jikan / Wikipedia) → rawImageUrl
  //   Cloudinary upload is intentionally deferred to Save.

  static Future<List<GeneratedCharacter>> generateCharacters({
    required String franchise,
    int count = 10,
    List<DraftCard> existingCards = const [],
    FranchiseCategory category = FranchiseCategory.other,
    String customContext = '',
  }) async {
    final existingNames = existingCards.map((c) => c.name).toList();

    final legendaryCount = existingCards.where((c) => c.level >= 9.0).length;
    final epicCount = existingCards.where((c) => c.level >= 7.0 && c.level < 9.0).length;

    final enumerationPreamble =
        'BEFORE YOU GENERATE — MANDATORY MENTAL STEP (do not skip):\n'
        'Step 1. Mentally list EVERY named character you know from "$franchise" '
            '— heroes, villains, monsters, allies, bosses, shadow soldiers, rulers, '
            'elite hunters — no matter how many there are.\n'
        'Step 2. Sort that full list from MOST famous / iconic / powerful '
            'down to LEAST known.\n'
        'Step 3. Cross out every name that already appears in the ALREADY EXISTS '
            'exclusion list below.\n'
        'Step 4. Pick your $count characters strictly from the TOP of that sorted, '
            'filtered list — working downward only as far as needed.\n'
        'CRITICAL RULE: NEVER fill a slot with a generic, unnamed, or descriptive '
        'character (e.g. "Weak Hunter", "Guild Member", "Random Soldier", '
        '"Anonymous Hunter", "Low-Rank Monster") while any important NAMED character '
        'from the same franchise is still uncatalogued. '
        'A named character with even a minor role is ALWAYS preferred over a filler entry.\n'
        'If you are unsure whether a character qualifies, INCLUDE them — '
        'it is always better to add a named character than to generate filler.\n\n';

    String focusTierInstruction;
    if (existingCards.isEmpty || legendaryCount < 3) {
      focusTierInstruction =
          '$enumerationPreamble'
          'GENERATION PHASE: LEGENDARY FIRST\n'
          'The catalogue for "$franchise" is '
          '${existingCards.isEmpty ? "empty (first batch)" : "low on Legendary cards ($legendaryCount so far)"}.\n'
          'PRIMARY GOAL: Generate the most iconic, universally well-known Legendary '
          'characters first.\n\n'
          'STRICT PRIORITY ORDER:\n'
          '1. LEGENDARY (level 9.0–10.0) — The absolute icons every fan knows by name. '
              'Aim for AT LEAST ${(count * 0.55).round()} Legendary cards in this batch.\n'
          '2. EPIC     (level 7.0–8.9)  — Fill remaining slots with the next tier of '
              'well-known NAMED characters.\n'
          '3. RARE / COMMON             — ONLY if truly no more well-known named Legendary '
              'or Epic characters remain uncatalogued.\n\n'
          'DO NOT generate unnamed, generic, or obscure characters while any important '
          'named Legendary or Epic character has not yet been catalogued.\n';
    } else if (epicCount < 3) {
      focusTierInstruction =
          '$enumerationPreamble'
          'GENERATION PHASE: EPIC FOCUS\n'
          'The most iconic Legendary characters ($legendaryCount already catalogued) are covered.\n'
          'PRIMARY GOAL: Generate the well-known Epic-tier NAMED characters not yet added.\n\n'
          'STRICT PRIORITY ORDER:\n'
          '1. EPIC     (level 7.0–8.9)  — Well-known named characters clearly recognisable '
              'to any fan of the franchise. '
              'Aim for AT LEAST ${(count * 0.55).round()} Epic cards in this batch.\n'
          '2. LEGENDARY (level 9.0–10.0) — ONLY if a well-known Legendary character was '
              'genuinely missed and is not in the exclusion list.\n'
          '3. RARE     (level 4.0–6.9)  — Fill remaining slots with notable NAMED secondary characters.\n'
          '4. COMMON   (level 1.0–3.9)  — Keep to an absolute minimum; no generic filler.\n\n'
          'DO NOT generate unnamed or obscure filler while well-known named Epic characters '
          'have not yet been catalogued.\n';
    } else {
      focusTierInstruction =
          '$enumerationPreamble'
          'GENERATION PHASE: RARE & COMMON\n'
          'The well-known Legendary ($legendaryCount) and Epic ($epicCount) named characters '
          'are already catalogued.\n'
          'PRIMARY GOAL: Generate the remaining secondary and supporting NAMED characters.\n\n'
          'STRICT PRIORITY ORDER:\n'
          '1. RARE   (level 4.0–6.9) — Named supporting characters, secondary antagonists, '
              'recurring side characters with meaningful named roles.\n'
          '2. COMMON (level 1.0–3.9) — Named minor characters, brief appearances, '
              'comic-relief roles. Use unnamed/generic entries ONLY as an absolute last '
              'resort when truly no more named characters exist.\n'
          '3. Do NOT add more Legendary or Epic cards unless a genuinely well-known named '
              'character was missed (verify against the exclusion list).\n';
    }

    if (_apiKey.isEmpty) {
      throw Exception(
        'Groq API key is not configured.\n'
        'Run with:\n'
        '  --dart-define=GROQ_API_KEY=gsk_...\n'
        'Get a free key at console.groq.com/keys',
      );
    }

    // Step 1 — Groq
    final characters = await _generateCharacters(
        franchise, count, existingNames, category, customContext, focusTierInstruction);

    // Step 2 — Fetch raw preview image URLs (no Cloudinary upload yet)
    if (category == FranchiseCategory.anime) {
      for (final char in characters) {
        char.rawImageUrl = await _fetchFromJikan(char.name);
      }
    } else {
      final rawUrls = await Future.wait(
        characters.map((c) => _fetchFromWikipedia(c.name, franchise: franchise)),
      );
      for (int i = 0; i < characters.length; i++) {
        characters[i].rawImageUrl = rawUrls[i];
      }
    }

    return characters;
  }

  // ── Step 1: Groq ──────────────────────────────────────────────────────────

  static Future<List<GeneratedCharacter>> _generateCharacters(
      String franchise, int count, List<String> existingNames,
      FranchiseCategory category, String customContext, String focusTierInstruction) async {

    final exclusionClause = existingNames.isEmpty
        ? ''
        : '\n\nIMPORTANT — The following entries ALREADY EXIST in the catalogue. '
          'Do NOT include any of them (not even slight name variations):\n'
          '${existingNames.map((n) => '  - $n').join('\n')}\n'
          'Generate $count DIFFERENT entries NOT in the list above.';

    final int commonCap = (count * 0.10).floor().clamp(1, count);

    const priorityRule = "";

    final String prompt;

    switch (category) {

      case FranchiseCategory.sports:
        prompt =
            'You are a sports game card designer.\n'
            'List exactly $count real players who play for or are iconic to "$franchise".\n'
            '$priorityRule\n\n'
            'Return ONLY a valid JSON array — no markdown, no extra text, no code fences.\n'
            'Each object must have:\n'
            '  - "name": string — player\'s full real name\n'
            '  - "description": string — 1 sentence, max 200 chars, their position + notable skill\n'
            '  - "level": number — DECIMAL 1.0–10.0 reflecting their real-world skill/fame\n\n'
            'LEVEL = RARITY TIER:\n'
            '  9.5–10.0 = MYTHIC    — GOAT-level, undisputed all-time legends\n'
            '  8.0–9.4  = LEGENDARY — world-class superstars, hall of famers\n'
            '  6.0–7.9  = EPIC      — established stars, key squad players\n'
            '  3.5–5.9  = RARE      — solid squad members, fringe internationals\n'
            '  1.0–3.4  = COMMON    — reserve/academy players — MAX $commonCap in this list\n\n'
            'Use decimals freely (e.g. 8.4, 6.1, 4.7). Spread levels realistically.\n\n'
            'Example output for 3 FC Barcelona players (most famous first):\n'
            '[\n'
            '  {"name":"Lamine Yamal","description":"Electric right winger with exceptional dribbling and vision.","level":8.6},\n'
            '  {"name":"Robert Lewandowski","description":"Clinical striker and prolific goal-scorer.","level":8.2},\n'
            '  {"name":"Pau Cubarsi","description":"Young central defender known for composure under pressure.","level":6.5}\n'
            ']$exclusionClause';
        break;

      case FranchiseCategory.movie:
        prompt =
            'You are a game card designer for a character draft game.\n'
            'Generate exactly $count characters from the "$franchise" movie/film franchise.\n'
            '$priorityRule\n\n'
            'Return ONLY a valid JSON array — no markdown, no extra text, no code fences.\n'
            'Each object must have:\n'
            '  - "name": string — character\'s full name as known in the film\n'
            '  - "description": string — 1 sentence, max 200 chars, their role/ability in the story\n'
            '  - "level": number — DECIMAL 1.0–10.0 reflecting their power/importance in the film\n\n'
            'LEVEL = RARITY TIER:\n'
            '  9.5–10.0 = MYTHIC    — god-tier, the absolute face of the franchise\n'
            '  8.0–9.4  = LEGENDARY — main heroes/villains, series icons\n'
            '  6.0–7.9  = EPIC      — major protagonists and key antagonists\n'
            '  3.5–5.9  = RARE      — supporting characters with meaningful roles\n'
            '  1.0–3.4  = COMMON    — minor/background characters — MAX $commonCap in this list\n\n'
            'Use decimals freely. Spread levels realistically.\n\n'
            'Example output for 3 Harry Potter characters (most famous first):\n'
            '[\n'
            '  {"name":"Albus Dumbledore","description":"Wise and immensely powerful headmaster who guides Harry against Voldemort.","level":9.6},\n'
            '  {"name":"Hermione Granger","description":"Brilliant witch and loyal companion with exceptional magical talent.","level":8.1},\n'
            '  {"name":"Neville Longbottom","description":"Brave Gryffindor student who grows into an unexpected hero.","level":5.8}\n'
            ']$exclusionClause';
        break;

      case FranchiseCategory.game:
        prompt =
            'You are a game card designer for a character draft game.\n'
            'Generate exactly $count characters from the "$franchise" video game franchise.\n'
            '$priorityRule\n\n'
            'Return ONLY a valid JSON array — no markdown, no extra text, no code fences.\n'
            'Each object must have:\n'
            '  - "name": string — character\'s full in-game name\n'
            '  - "description": string — 1 sentence, max 200 chars, their class/ability/role\n'
            '  - "level": number — DECIMAL 1.0–10.0 reflecting their in-game power/importance\n\n'
            'LEVEL = RARITY TIER:\n'
            '  9.5–10.0 = MYTHIC    — final boss at absolute peak / most iconic protagonist\n'
            '  8.0–9.4  = LEGENDARY — elite antagonist / beloved series hero\n'
            '  6.0–7.9  = EPIC      — main hero / fan-favourite / major boss\n'
            '  3.5–5.9  = RARE      — strong party members, key NPCs\n'
            '  1.0–3.4  = COMMON    — tutorial enemies, weak side-characters — MAX $commonCap in this list\n\n'
            'Use decimals freely. Spread levels realistically.\n\n'
            'Example output for 3 Legend of Zelda characters (most famous first):\n'
            '[\n'
            '  {"name":"Ganondorf","description":"The Gerudo King wielding the Triforce of Power with divine dark magic.","level":9.7},\n'
            '  {"name":"Link","description":"The hero of time armed with legendary weapons and courage.","level":8.5},\n'
            '  {"name":"Tingle","description":"An eccentric map-maker with no combat skill whatsoever.","level":1.2}\n'
            ']$exclusionClause';
        break;

      case FranchiseCategory.comics:
        prompt =
            'You are a game card designer for a character draft game.\n'
            'Generate exactly $count characters from the "$franchise" comics universe.\n'
            '$priorityRule\n\n'
            'Return ONLY a valid JSON array — no markdown, no extra text, no code fences.\n'
            'Each object must have:\n'
            '  - "name": string — the hero/villain\'s full name or most recognised alias\n'
            '  - "description": string — 1 sentence, max 200 chars, their superpower/role\n'
            '  - "level": number — DECIMAL 1.0–10.0 reflecting their power tier\n\n'
            'LEVEL = RARITY TIER:\n'
            '  9.5–10.0 = MYTHIC    — cosmic/omnipotent beings, the absolute pinnacle\n'
            '  8.0–9.4  = LEGENDARY — god-level heroes and the biggest villain names\n'
            '  6.0–7.9  = EPIC      — primary antagonists and major well-known heroes\n'
            '  3.5–5.9  = RARE      — street-level powerhouses, well-known heroes\n'
            '  1.0–3.4  = COMMON    — civilians or comic-relief characters — MAX $commonCap in this list\n\n'
            'Use decimals freely. Spread levels realistically.\n\n'
            'Example output for 3 Marvel characters (most famous first):\n'
            '[\n'
            '  {"name":"Thanos","description":"The Mad Titan capable of reshaping reality with the Infinity Gauntlet.","level":9.8},\n'
            '  {"name":"Spider-Man","description":"Agile wall-crawler with spider-sense and web-slinging abilities.","level":7.2},\n'
            '  {"name":"Aunt May","description":"Peter Parker\'s caring aunt with no combat abilities.","level":1.3}\n'
            ']$exclusionClause';
        break;

      case FranchiseCategory.anime:
        prompt =
            'You are a game card designer for a character draft game.\n'
            'Generate exactly $count characters from the "$franchise" anime/manga series.\n'
            '$priorityRule\n\n'
            'Return ONLY a valid JSON array — no markdown, no extra text, no code fences.\n'
            'Each object must have:\n'
            '  - "name": string — the character\'s well-known full name\n'
            '  - "description": string — 1 sentence, max 200 characters, about their power/role\n'
            '  - "level": number — a DECIMAL from 1.0 to 10.0 reflecting their TRUE power level\n\n'
            'LEVEL = RARITY TIER:\n'
            '  9.5–10.0 = MYTHIC    — absolute god-tier, the single most powerful/iconic\n'
            '  8.0–9.4  = LEGENDARY — top-tier, series icons, protagonist at peak\n'
            '  6.0–7.9  = EPIC      — elite rivals, key villains, major fan-favourites\n'
            '  3.5–5.9  = RARE      — above-average fighters, solid side characters\n'
            '  1.0–3.4  = COMMON    — weak, civilian-level, fodder — MAX $commonCap in this list\n\n'
            'Use decimals freely (e.g. 9.3, 7.8, 5.1, 4.6). Spread levels realistically.\n\n'
            'Example output for 3 Naruto characters (most famous first):\n'
            '[\n'
            '  {"name":"Naruto Uzumaki","description":"The unpredictable ninja who mastered sage mode and became Hokage.","level":8.7},\n'
            '  {"name":"Sasuke Uchiha","description":"The last Uchiha who mastered the Sharingan and Rinnegan.","level":8.5},\n'
            '  {"name":"Iruka Umino","description":"A kind-hearted teacher with average combat skills.","level":2.4}\n'
            ']$exclusionClause';
        break;

      default:
        final contextLine = customContext.trim().isNotEmpty
            ? 'Additional context about this franchise: $customContext\n\n'
            : '';
        prompt =
            'You are a game card designer for a character draft game.\n'
            'Generate exactly $count notable characters/entities for the "$franchise" franchise.\n'
            '$contextLine$priorityRule\n\n'
            'Return ONLY a valid JSON array — no markdown, no extra text, no code fences.\n'
            'Each object must have:\n'
            '  - "name": string — the entity\'s full name\n'
            '  - "description": string — 1 sentence, max 200 chars, about their role/power\n'
            '  - "level": number — DECIMAL 1.0–10.0 reflecting their power/significance\n\n'
            'LEVEL = RARITY TIER:\n'
            '  9.5–10.0 = MYTHIC    — supreme, god-like, the ultimate icon\n'
            '  8.0–9.4  = LEGENDARY — all-powerful, central to the lore\n'
            '  6.0–7.9  = EPIC      — very strong, key to the story\n'
            '  3.5–5.9  = RARE      — solid supporting role, secondary figures\n'
            '  1.0–3.4  = COMMON    — weak, minor, background — MAX $commonCap in this list\n\n'
            'Use decimals freely. Spread levels realistically.$exclusionClause';
        break;
    }

    late http.Response response;
    try {
      response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model':    _model,
          'messages': [
            {
              'role':    'system',
              'content':
                  'You are a game design assistant with deep knowledge of anime, manga, '
                  'movies, games, comics, and sports franchises. '
                  'MOST IMPORTANT RULE: Before generating any characters, mentally enumerate '
                  'every named character in the requested franchise, sort them by fame and '
                  'importance, remove already-catalogued ones, then pick strictly from the '
                  'top of that sorted list. '
                  'NEVER fill a slot with a generic, unnamed, or obscure character '
                  '(e.g. "Weak Hunter", "Random Soldier", "Guild Member") while any '
                  'important named character from that franchise is still uncatalogued. '
                  'Output ONLY a raw JSON array with no markdown, no explanation, and no '
                  'code fences. All level values must be decimal numbers (e.g. 7.5, not 7).',
            },
            {
              'role':    'user',
              'content': prompt,
            },
          ],
          'temperature': 0.6,
          'max_tokens':  3000,
        }),
      ).timeout(const Duration(seconds: 45));
    } catch (e) {
      throw Exception('Network error: $e');
    }

    if (response.statusCode == 401) {
      throw Exception('Invalid Groq API key. Check --dart-define=GROQ_API_KEY.');
    }
    if (response.statusCode == 429) {
      throw Exception('Rate limit exceeded. Wait a moment and try again.');
    }
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      final msg = err['error']?['message'] ?? response.body;
      throw Exception('Groq API error: $msg');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Failed to parse Groq response envelope.');
    }

    final content = (json['choices'] as List?)
        ?.firstOrNull
        ?['message']?['content'] as String?;

    if (content == null || content.trim().isEmpty) {
      throw Exception('Groq returned an empty response.');
    }

    return _parseCharacters(content);
  }

  // ── JSON parser ───────────────────────────────────────────────────────────

  static List<GeneratedCharacter> _parseCharacters(String raw) {
    var cleaned = raw
        .replaceAll(RegExp(r'```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'```\s*',     multiLine: true), '')
        .trim();

    final start = cleaned.indexOf('[');
    if (start == -1) {
      throw Exception('No JSON array found in response.\n\nRaw: $cleaned');
    }
    cleaned = cleaned.substring(start);

    if (!cleaned.trimRight().endsWith(']')) {
      final lastBrace = cleaned.lastIndexOf('}');
      if (lastBrace != -1) {
        cleaned = '${cleaned.substring(0, lastBrace + 1)}]';
      } else {
        throw Exception('Response too truncated to recover.\n\nRaw: $cleaned');
      }
    }

    final List<dynamic> parsed;
    try {
      parsed = jsonDecode(cleaned) as List<dynamic>;
    } catch (_) {
      throw Exception('Could not parse character JSON.\n\nRaw: $cleaned');
    }

    return parsed.map((item) {
      final m = item as Map<String, dynamic>;
      // Accept both 'level' and 'power_level' keys
      final rawLevel = ((m['level'] ?? m['power_level']) as num?)?.toDouble() ?? 5.0;
      return GeneratedCharacter(
        name:        (m['name']        as String? ?? 'Unknown').trim(),
        description: (m['description'] as String? ?? '').trim(),
        level:       rawLevel.clamp(1.0, 10.0),
      );
    }).toList();
  }

  // ── Jikan image URL (MyAnimeList, free, no key) ───────────────────────────

  /// Public alias so callers outside this file (e.g. Paste JSON mode) can fetch.
  static Future<String> fetchJikanImage(String name) => _fetchFromJikan(name);

  /// Public alias for Wikipedia image fetch. Pass franchise for more accurate results.
  static Future<String> fetchWikipediaImage(String name, {String franchise = ''}) =>
      _fetchFromWikipedia(name, franchise: franchise);

  static Future<String> _fetchFromJikan(String characterName) async {
    try {
      await Future.delayed(_jikanDelay);
      final uri = Uri.parse(
        'https://api.jikan.moe/v4/characters'
        '?q=${Uri.encodeComponent(characterName)}'
        '&limit=1',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return '';

      final data = (jsonDecode(res.body) as Map<String, dynamic>)['data']
          as List<dynamic>?;
      if (data == null || data.isEmpty) return '';

      final jpg = (data[0]['images'] as Map<String, dynamic>?)?['jpg']
          as Map<String, dynamic>?;
      return (jpg?['image_url'] as String?)
          ?? (jpg?['small_image_url'] as String?)
          ?? '';
    } catch (_) {
      return '';
    }
  }

  // ── Wikipedia image (free, no key) ───────────────────────────────────────

  static Future<String> _fetchFromWikipedia(String name, {String franchise = ''}) async {
    final searchTitle = franchise.isNotEmpty ? '$name $franchise' : name;
    try {
      final uri = Uri.parse(
        'https://en.wikipedia.org/w/api.php'
        '?action=query'
        '&titles=${Uri.encodeComponent(searchTitle)}'
        '&prop=pageimages'
        '&format=json'
        '&pithumbsize=300'
        '&redirects=1',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return '';

      final body  = jsonDecode(res.body) as Map<String, dynamic>;
      final pages = (body['query']?['pages'] as Map<String, dynamic>?) ?? {};
      if (pages.isEmpty) return '';

      final page = pages.values.first as Map<String, dynamic>;
      return (page['thumbnail']!['source'] as String);
    } catch (_) {
      return _fetchFromDuckDuckGo(franchise.isNotEmpty ? '$name $franchise' : name);
    }
  }

  static Future<String> _fetchFromDuckDuckGo(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);

      final res1 = await http
          .get(Uri.parse('https://duckduckgo.com/?q=$encodedQuery'))
          .timeout(const Duration(seconds: 8));

      final token = RegExp(r'vqd="(.*?)"').firstMatch(res1.body)?.group(1);
      if (token == null) return '';

      final url = 'https://duckduckgo.com/i.js?q=$encodedQuery&vqd=$token&o=json';
      final res2 = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));

      if (res2.statusCode != 200) return '';

      final data    = jsonDecode(res2.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return '';

      return (results[0]['image'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Converts a [GeneratedCharacter] into a [DraftCard] ready for Firestore.
  /// Call this AFTER imageUrl has been populated by Cloudinary upload.
  static DraftCard toCard({
    required GeneratedCharacter character,
    required String franchiseId,
    required String franchiseName,
  }) {
    return DraftCard(
      id:            '',
      franchiseIds:  franchiseId.isNotEmpty ? [franchiseId] : [],
      franchiseName: franchiseName,
      name:          character.name,
      description:   character.description,
      level:         character.level,
      imageUrl:      character.imageUrl,
    );
  }

  static bool get isConfigured => _apiKey.isNotEmpty;

  // ── Normalise any free-text / JSON response into GeneratedCharacter list ──
  //
  // Sends the raw pasted text to Groq and asks it to extract / normalise
  // characters into a strict JSON array with name, description, power_level.
  // Works with any format: plain prose, partial JSON, wrapped objects, etc.

  static Future<List<GeneratedCharacter>> normaliseToCharacters(String rawInput) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'Groq API key is not configured.\n'
        'Run with:\n'
        '  --dart-define=GROQ_API_KEY=gsk_...\n'
        'Get a free key at console.groq.com/keys',
      );
    }

    const systemPrompt =
        'You are a data extraction assistant. '
        'The user will give you text in ANY format — JSON, prose, a list, a table, '
        'partial data, wrapped objects, or anything else. '
        'Your ONLY job is to extract every character / entity mentioned and return '
        'a clean JSON array. Each object MUST have exactly these three fields:\n'
        '  - "name": string — the character full name\n'
        '  - "description": string — 1–2 sentences about their role or power\n'
        '  - "power_level": number — MUST be a decimal e.g. 8.7, 10.0, 5.2 — NEVER a plain integer like 8 or 10\n'
        'Rules:\n'
        '• If the input already has level/power_level/score fields, copy the value exactly as-is (preserve decimals).\n'
        '• If no level is present, infer a reasonable power_level from the description.\n'
        '• NEVER round to whole numbers — always use one decimal place (e.g. 10.0 not 10, 7.0 not 7).\n'
        '• Do NOT add, invent or omit characters — extract exactly what is in the input.\n'
        '• Output ONLY the raw JSON array. No markdown, no code fences, no explanation.';

    late http.Response response;
    try {
      response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model':    _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user',   'content': rawInput},
          ],
          'temperature': 0.2,
          'max_tokens':  4000,
        }),
      ).timeout(const Duration(seconds: 45));
    } catch (e) {
      throw Exception('Network error: $e');
    }

    if (response.statusCode == 401) throw Exception('Invalid Groq API key.');
    if (response.statusCode == 429) throw Exception('Rate limit exceeded. Try again shortly.');
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception('Groq error: ${err['error']?['message'] ?? response.body}');
    }

    final content = (jsonDecode(response.body)['choices'] as List?)
        ?.firstOrNull?['message']?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw Exception('Groq returned an empty response.');
    }

    return _parseCharacters(content);
  }
}
