/**
 * DraftClash — Cloud Functions
 *
 * generateFranchiseCards
 *   1. Uses Gemini 1.5 Flash to generate 8 iconic characters for a franchise.
 *   2. For each character, fetches a face image via Google Custom Search API.
 *   3. Writes all cards to Firestore `cards/` collection in a single batch.
 *
 * Required environment variables (set via Firebase secret or .env.local):
 *   GEMINI_API_KEY          — Google AI Studio API key
 *   GOOGLE_CSE_API_KEY      — Google Custom Search API key
 *   GOOGLE_CSE_CX           — Custom Search Engine ID (image search enabled)
 *
 * Setup:
 *   firebase functions:secrets:set GEMINI_API_KEY
 *   firebase functions:secrets:set GOOGLE_CSE_API_KEY
 *   firebase functions:secrets:set GOOGLE_CSE_CX
 *
 *   OR for local dev, create functions/.env.local with the three vars above.
 *
 * Deploy:
 *   cd functions && npm install && cd .. && firebase deploy --only functions
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp }      = require('firebase-admin/app');
const { getFirestore }       = require('firebase-admin/firestore');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const https                  = require('https');

initializeApp();

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Fetch a character face image URL via Google Custom Search API (image mode).
 * Returns an empty string if nothing is found or the request fails.
 *
 * @param {string} geminiQuery    Gemini-provided imageSearchQuery (preferred)
 * @param {string} characterName  fallback: character full name
 * @param {string} franchise      fallback: franchise name
 * @param {string} apiKey         GOOGLE_CSE_API_KEY
 * @param {string} cx             GOOGLE_CSE_CX
 */
function fetchCharacterImage(geminiQuery, characterName, franchise, apiKey, cx) {
  return new Promise((resolve) => {
    // Use Gemini's curated query if available, otherwise build a generic one
    const rawQuery = (geminiQuery && geminiQuery.trim())
      ? geminiQuery.trim()
      : `${characterName} ${franchise} anime character face portrait`;
    const query = encodeURIComponent(rawQuery);

    console.log(`[image search] query: "${rawQuery}"`);

    const url =
      `https://www.googleapis.com/customsearch/v1` +
      `?key=${apiKey}` +
      `&cx=${cx}` +
      `&q=${query}` +
      `&searchType=image` +       // image-only search
      `&imgType=face` +            // face-type images
      `&imgSize=medium` +          // medium size: good balance for card UI
      `&safe=active` +             // safe search on
      `&num=1`;                    // only need the top result

    https.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const json  = JSON.parse(data);
          const items = json.items;
          if (items && items.length > 0) {
            // Prefer the thumbnail (smaller, loads faster in card UI)
            const item      = items[0];
            const thumbLink = item.image?.thumbnailLink;
            const fullLink  = item.link;
            resolve(thumbLink || fullLink || '');
          } else {
            resolve('');
          }
        } catch (_) {
          resolve('');
        }
      });
      res.on('error', () => resolve(''));
    }).on('error', () => resolve(''));
  });
}

/**
 * Safely parse a JSON string that may be wrapped in markdown code fences.
 */
function safeParseJson(raw) {
  const cleaned = raw
    .replace(/```json/gi, '')
    .replace(/```/g, '')
    .trim();
  return JSON.parse(cleaned);
}

// ─────────────────────────────────────────────────────────────────────────────
// Cloud Function
// ─────────────────────────────────────────────────────────────────────────────

exports.generateFranchiseCards = onCall(
  {
    // Declare secrets so Firebase injects them as env vars at runtime
    secrets: ['GEMINI_API_KEY', 'GOOGLE_CSE_API_KEY', 'GOOGLE_CSE_CX'],
    // Allow up to 120 s — image fetches for 8 characters can take a moment
    timeoutSeconds: 120,
  },
  async (request) => {
    // ── Auth guard ──────────────────────────────────────────────────────────
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'You must be logged in.');
    }

    const franchise = (request.data?.franchise || '').trim();
    if (!franchise) {
      throw new HttpsError('invalid-argument', '`franchise` is required.');
    }

    // ── Read secrets ────────────────────────────────────────────────────────
    const geminiKey = process.env.GEMINI_API_KEY;
    const cseKey    = process.env.GOOGLE_CSE_API_KEY;
    const cseCx     = process.env.GOOGLE_CSE_CX;

    if (!geminiKey) {
      throw new HttpsError('internal', 'GEMINI_API_KEY is not configured.');
    }

    // ── Step 1: Generate characters with Gemini ─────────────────────────────
    const genAI = new GoogleGenerativeAI(geminiKey);
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

    const prompt = `List the top 8 most iconic characters from the franchise "${franchise}".
Return ONLY a valid JSON array. Each object must have exactly these keys:
- "name"             (string) full character name
- "description"      (string) max 2 sentences about their power and role
- "level"            (integer 1–10, where 10 = most powerful in the franchise)
- "imageSearchQuery" (string) the single best Google image search query to find
                     a clear face/portrait image of this character.
                     Rules for imageSearchQuery:
                       • Include the character full name and franchise title
                       • Add the medium type: "anime" for anime, "marvel comics" for comics, etc.
                       • End with one of: "face", "portrait", or "close up"
                       • Keep it under 10 words
                       • Example: "Itachi Uchiha Naruto Shippuden anime face"

Assign levels carefully:
  10 = absolute apex (god-tier, final-boss level)
  8–9 = elite / main protagonist
  6–7 = strong supporting cast
  4–5 = mid-tier fighters or key side characters
  1–3 = weaker or comic-relief characters

No markdown. No extra text. Only the JSON array.`;

    let characters;
    try {
      const result = await model.generateContent(prompt);
      const text   = result.response.text();
      characters   = safeParseJson(text);

      if (!Array.isArray(characters) || characters.length === 0) {
        throw new Error('Gemini returned an empty or invalid array.');
      }
    } catch (err) {
      console.error('Gemini error:', err);
      throw new HttpsError('internal', `AI generation failed: ${err.message}`);
    }

    // ── Step 2: Fetch face images in parallel ───────────────────────────────
    let imageUrls;
    if (cseKey && cseCx) {
      imageUrls = await Promise.all(
        characters.map((char) =>
          fetchCharacterImage(
            char.imageSearchQuery,  // Gemini's curated query
            char.name,              // fallback name
            franchise,              // fallback franchise
            cseKey,
            cseCx
          )
        )
      );
    } else {
      // CSE not configured — proceed without images (graceful degradation)
      console.warn(
        'GOOGLE_CSE_API_KEY or GOOGLE_CSE_CX not set. Skipping image fetch.'
      );
      imageUrls = characters.map(() => '');
    }

    // ── Step 3: Write to Firestore ──────────────────────────────────────────
    const db    = getFirestore();
    const batch = db.batch();
    let count   = 0;

    for (let i = 0; i < characters.length; i++) {
      const char  = characters[i];
      const level = Math.min(10, Math.max(1, parseInt(char.level) || 5));

      const ref = db.collection('cards').doc();
      batch.set(ref, {
        franchise,
        name:        (char.name        || 'Unknown').trim(),
        description: (char.description || '').trim(),
        level,
        imageUrl:    imageUrls[i] || '',
        createdAt:   new Date(),
      });
      count++;
    }

    await batch.commit();

    console.log(`Generated ${count} cards for franchise "${franchise}"`);
    return { cardsAdded: count, franchise };
  }
);
