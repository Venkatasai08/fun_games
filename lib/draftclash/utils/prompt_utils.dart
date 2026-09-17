// lib/draftclash/utils/prompt_utils.dart
//
// Generic prompt-generation utilities shared across admin screens and cards.
// Import this wherever you need to build an AI character-generation prompt.
//

import 'package:fun_games/draftclash/models/draft_card.dart';

/// Builds a structured character-generation prompt for [seriesName].
///
/// [count]       — how many characters to request (e.g. 10, 50).
/// [excludeList] — character names already in the game; the AI must skip them.
///
/// Usage:
///   final prompt = generateCharacters('Baki', 50,
///       excludeList: ['Baki Hanma', 'Yujiro Hanma']);
///   await Clipboard.setData(ClipboardData(text: prompt));
String generateCharactersOld(
  String seriesName,
  int count, {
  List<String> excludeList = const [],
}) {
  final exclusionBlock = excludeList.isNotEmpty
      ? excludeList.map((name) => '- $name').join('\n')
      : 'None';

  return '''
You are an expert fictional character analyst and power-scaling system.
Generate $count unique characters from the series: $seriesName.
-------------------------------------
OUTPUT FORMAT:
{
  "characters": [
    {
      "name": "string",
      "description": "max 120 characters, no line breaks",
      "power_level": number (1.0 to 10.0, decimals allowed)
    }
  ]
}
-------------------------------------
RULES:
1. POWER SCALING
- Relative to the $seriesName universe only.
- Use strongest canon version of each character.
Scale:
10.0 → Absolute top / god-tier
9.5–9.9 → Near-absolute top
9.0–9.4 → Top-tier
8.0–8.9 → High-tier
7.0–7.9 → Strong
6.0–6.9 → Mid
5.0–5.9 → Low-mid
1.0–4.9 → Weak
-------------------------------------
2. ACCURACY
- Use only canon feats.
- Consider transformations / peak forms.
- No exaggeration or fan bias.
-------------------------------------
3. CHARACTER RULES
- Only well-known, relevant characters.
- No duplicates.
-------------------------------------
4. EXCLUSION (CRITICAL)
Do NOT include any of these characters:
$exclusionBlock
Ensure all generated characters are UNIQUE and not in this list.
-------------------------------------
5. DESCRIPTION
- Max 120 characters
- Short and clear
- No line breaks
-------------------------------------
6. OUTPUT
- ONLY JSON
- No explanation
- No markdown
-------------------------------------
Generate the dataset now.''';
}

String generateCharactersSecondOld({
  required String seriesName,
  required int count,
  List<String> excludeList = const [],
}) {
  final exclusions = excludeList.isNotEmpty
      ? excludeList.map((e) => "- $e").join("\n")
      : "None";

  return """
You are an expert character and entity power-scaling system.

Your task is to generate a highly accurate, CONSISTENT, and well-balanced dataset.

-------------------------------------

INPUT:
Series: $seriesName
Number of entities: $count

-------------------------------------

OUTPUT FORMAT:

{
  "characters": [
    {
      "name": "string",
      "description": "max 120 characters, no line breaks",
      "power_level": number (1.0 to 10.0, decimals allowed)
    }
  ]
}

-------------------------------------

CORE RULE (CRITICAL)

Power levels must be PRECISE, CONSISTENT, and DIFFERENCE-BASED.

-------------------------------------

1. TOP ENTITY RULE

- Identify the strongest entity
- Assign EXACTLY: 10.0
- If multiple absolute top-tier entities exist, they can ALSO be 10.0

-------------------------------------

2. CONSISTENT DIFFERENCE SYSTEM (VERY IMPORTANT)

You MUST follow a structured gap system:

- Same tier / equals → SAME or ±0.1 difference
- Very close rivals → 0.1–0.2 difference
- Slightly weaker → 0.2–0.4 difference
- Clearly weaker → 0.5–1.0 difference
- Much weaker tiers → drop to next whole range (8.x, 7.x, etc.)

Example logic:
- 10.0 → absolute top
- 9.9 → almost equal
- 9.7 → slightly below
- 9.4 → noticeable gap
- 8.8 → clear tier drop
- 7.x → mid-high
- 5.x → average
- 2–3 → weak / non-combat

-------------------------------------

3. DISTRIBUTION RULE

- Spread characters across FULL range (1.0 → 10.0)
- Do NOT cluster everyone in 9.x
- Weak characters MUST be in lower ranges (1–4)

-------------------------------------

4. DOMAIN ADAPTATION

- Fictional → strength, feats, transformations
- Sports → skill, dominance, achievements
- Real-world → influence, impact

-------------------------------------

5. ACCURACY RULES

- Use canon / real / accepted data only
- No random numbers
- No bias or exaggeration
- Maintain INTERNAL CONSISTENCY

-------------------------------------

6. CHARACTER RULES

- Only well-known entities
- No duplicates

-------------------------------------

7. EXCLUSION RULE

Do NOT include:
$exclusions

-------------------------------------

8. DESCRIPTION RULES

- Max 120 characters
- Clear and informative
- No line breaks

-------------------------------------

9. OUTPUT RULES

- ONLY JSON
- No explanation
- No markdown
- No extra text

-------------------------------------

Generate the dataset now.
""";
}

String generateCharactersThirdOld({
  required String seriesName,
  required String category,
  required int count,
  List<DraftCard> existingCards = const [],
}) {
  final hasExisting = existingCards.isNotEmpty;

  final existingData = hasExisting
      ? existingCards.map((e) => "- ${e.name}: ${e.level}").join("\n")
      : "None";

  return """
You are an expert entity power-scaling system.

Your task is to generate NEW draft cards with HIGHLY ACCURATE, CONSISTENT, and PRECISE power levels.

-------------------------------------

INPUT:
Name: $seriesName
Category: $category
Number of NEW cards: $count

-------------------------------------

EXISTING ENTITIES WITH LEVELS:

$existingData

-------------------------------------

OUTPUT FORMAT:

{
  "cards": [
    {
      "name": "string",
      "description": "max 120 characters",
      "level": number (1.0 to 10.0, decimals allowed)
    }
  ]
}

-------------------------------------

CORE SCALING MODE (AUTO SWITCH)

${hasExisting ? """
MODE: ANCHORED SCALING (EXISTING DATA PRESENT)

- Use the existing entities as ABSOLUTE reference
- DO NOT change their levels
- Scale all new entities relative to them

Example:
If:
- Goku = 9.5

Then:
- Slightly weaker → 9.3–9.4
- Equal → 9.5
- Stronger → 9.6–9.8
""" : """
MODE: FRESH SCALING (NO EXISTING DATA)

- Identify the strongest entity
- Assign EXACTLY: 10.0
- If multiple top-tier entities exist → they can also be 10.0
"""}

-------------------------------------

CONSISTENT DIFFERENCE SYSTEM (VERY IMPORTANT)

- Same level → SAME or ±0.1
- Very close → 0.1–0.2 gap
- Slightly weaker → 0.2–0.4 gap
- Clearly weaker → 0.5–1.0 gap
- Much weaker → drop to next tier range (8.x, 7.x, etc.)

Example:
10.0 → absolute top  
9.9 → almost equal  
9.7 → slightly below  
9.4 → noticeable gap  
8.8 → clear tier drop  
7.x → mid-high  
5.x → average  
2–3 → weak  

-------------------------------------

DISTRIBUTION RULE

- Spread across FULL range (1.0–10.0)
- Avoid clustering at top
- Weak entities MUST be in 1–4 range

-------------------------------------

CATEGORY INTERPRETATION

- anime / fictional:
  → strength, abilities, transformations

- sports:
  → skill, achievements, dominance

- games:
  → mastery, ranking, strategic ability

- movie:
  → character strength, role importance, feats

- real-world:
  → influence, recognition, impact

-------------------------------------

CHARACTER RULES

- Only well-known and relevant entities
- Must belong to $seriesName

${hasExisting ? """
- DO NOT include any entity already listed above
""" : ""}

-------------------------------------

DESCRIPTION RULES

- Max 120 characters
- Clear and concise
- No line breaks

-------------------------------------

OUTPUT RULES

- ONLY JSON
- No explanation
- No markdown
- Do NOT include id, imageUrl, etc.

-------------------------------------

Generate the dataset now.
""";
}

String generateCharactersFourthOld({
  required String seriesName,
  required String category,
  required int count,
  String? contextDescription, // <-- NEW
  List<DraftCard> existingCards = const [],
}) {
  final hasExisting = existingCards.isNotEmpty;

  final existingData = hasExisting
      ? existingCards.map((e) => "- ${e.name}: ${e.level}").join("\n")
      : "None";

  final contextBlock =
      (contextDescription != null && contextDescription.trim().isNotEmpty)
          ? """
-------------------------------------

SERIES CONTEXT (IMPORTANT):

$contextDescription

- Use this context to better understand the universe, characters, and scaling logic
- DO NOT override the core scaling rules
- Use it only to improve accuracy and descriptions
"""
          : "";

  return """
You are an expert entity power-scaling system.

Your task is to generate NEW draft cards with HIGHLY ACCURATE, CONSISTENT, and PRECISE power levels.

-------------------------------------

INPUT:
Name: $seriesName
Category: $category
Number of NEW cards: $count

$contextBlock

-------------------------------------

EXISTING ENTITIES WITH LEVELS:

$existingData

-------------------------------------

OUTPUT FORMAT:

{
  "cards": [
    {
      "name": "string",
      "description": "max 120 characters",
      "level": number (1.0 to 10.0, decimals allowed)
    }
  ]
}

-------------------------------------

CORE SCALING MODE (AUTO SWITCH)

${hasExisting ? """
MODE: ANCHORED SCALING

- Use existing entities as ABSOLUTE reference
- DO NOT change their levels
- Scale new entities relative to them
""" : """
MODE: FRESH SCALING

- Identify the strongest entity
- Assign EXACTLY: 10.0
- Multiple top-tier entities can also be 10.0
"""}

-------------------------------------

CONSISTENT DIFFERENCE SYSTEM (CRITICAL)

- Same level → SAME or ±0.1
- Very close → 0.1–0.2 gap
- Slightly weaker → 0.2–0.4 gap
- Clearly weaker → 0.5–1.0 gap
- Much weaker → drop to next tier range

-------------------------------------

DISTRIBUTION RULE

- Use full range (1.0–10.0)
- Avoid clustering at top
- Weak entities MUST be in 1–4 range

-------------------------------------

CATEGORY INTERPRETATION

- anime / fictional:
  → strength, abilities, transformations

- movie:
  → character strength, role importance, feats

- sports:
  → skill, achievements, dominance, consistency

- games:
  → mastery, ranking, strategy

- other:
  → infer based on context, impact, influence, or ability

-------------------------------------

CHARACTER RULES

- Only well-known and relevant entities
- Must belong to or relate to $seriesName

${hasExisting ? "- DO NOT include any entity already listed above" : ""}

-------------------------------------

DESCRIPTION RULES

- Max 120 characters
- Clear and concise
- No line breaks

-------------------------------------

OUTPUT RULES

- ONLY JSON
- No explanation
- No markdown
- Do NOT include id, imageUrl, etc.

-------------------------------------

Generate the dataset now.
""";
}

String generateCharacters({
  required String seriesName,
  required String category, // anime / movie / games / sports / other
  required int count,
  String? contextDescription,
  List<DraftCard> existingCards = const [],
}) {
  final hasExisting = existingCards.isNotEmpty;

  final existingData = hasExisting
      ? existingCards.map((e) => "- ${e.name}: ${e.level}").join("\n")
      : "None";

  final contextBlock =
      (contextDescription != null && contextDescription.trim().isNotEmpty)
          ? """
-------------------------------------

SERIES CONTEXT (IMPORTANT):

$contextDescription

- Use this to better understand the universe and scaling
- Do NOT override core scaling rules
"""
          : "";

  return """
You are an expert entity power-scaling system.

Your task is to generate NEW draft cards with HIGHLY ACCURATE, CONSISTENT, and PRECISE power levels.

-------------------------------------

INPUT:
Name: $seriesName
Category: $category
Number of NEW cards: $count

$contextBlock

-------------------------------------

EXISTING ENTITIES WITH LEVELS:

$existingData

-------------------------------------

OUTPUT FORMAT:

{
  "cards": [
    {
      "name": "string",
      "description": "max 120 characters",
      "level": number (1.0 to 10.0, decimals allowed)
    }
  ]
}

-------------------------------------

CORE SCALING MODE (AUTO SWITCH)

${hasExisting ? """
MODE: ANCHORED SCALING

- Use existing entities as ABSOLUTE reference
- DO NOT change their levels
- Scale new entities relative to them
""" : """
MODE: FRESH SCALING

- Identify the strongest entity
- Assign EXACTLY: 10.0
- Multiple top-tier entities can also be 10.0
"""}

-------------------------------------

CONSISTENT DIFFERENCE SYSTEM (CRITICAL)

- Same level → SAME or ±0.1
- Very close → 0.1–0.2 gap
- Slightly weaker → 0.2–0.4 gap
- Clearly weaker → 0.5–1.0 gap
- Much weaker → drop to next tier range (8.x, 7.x, etc.)

Example:
10.0 → absolute top  
9.9 → almost equal  
9.7 → slightly below  
9.4 → noticeable gap  
8.8 → clear tier drop  
7.x → mid-high  
5.x → average  
2–3 → weak  

-------------------------------------

DISTRIBUTION RULE

- Use full range (1.0–10.0)
- Avoid clustering at top
- Weak entities MUST be in 1–4 range

-------------------------------------

CATEGORY INTERPRETATION

- anime / fictional:
  → strength, abilities, transformations

- movie:
  → character strength, role importance, feats

- sports:
  → skill, achievements, dominance, consistency

- games:
  → mastery, ranking, strategy

- other:
  → evaluate based on impact, influence, ability, or importance

-------------------------------------

CHARACTER RULES

- Only well-known and relevant entities
- Must belong to or relate to $seriesName

${hasExisting ? "- DO NOT include any entity already listed above" : ""}

-------------------------------------

CHARACTER UNIQUENESS RULE (VERY IMPORTANT)

- Each character/entity must appear ONLY ONCE
- DO NOT create multiple versions/forms of the same character

Examples NOT allowed:
- Eren Yeager (Founding Titan)
- Eren Yeager (Attack Titan)

Instead:
- Use ONE entry: Eren Yeager
- Assign level based on strongest or most relevant form

- Do NOT include transformations, forms, or variants in names

-------------------------------------

DESCRIPTION RULES

- Max 120 characters
- Clear and concise
- No line breaks

-------------------------------------

OUTPUT RULES

- ONLY JSON
- No explanation
- No markdown
- Do NOT include id, imageUrl, franchiseIds, etc.

-------------------------------------

Generate the dataset now.
""";
}
