'use strict';

const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models';

/**
 * Calls Google Gemini over REST. Returns a function
 * generate({ system, user }) that resolves to the model's text reply.
 * Errors carry only a status number, never the request or response body.
 */
function createGeminiClient(env, fetchImpl = globalThis.fetch) {
  return async function generate({ system, user }) {
    const url = `${ENDPOINT}/${encodeURIComponent(env.GEMINI_MODEL)}:generateContent`;
    let response;
    try {
      response = await fetchImpl(url, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-goog-api-key': env.GEMINI_API_KEY,
        },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: system }] },
          contents: [{ role: 'user', parts: [{ text: user }] }],
          generationConfig: {
            responseMimeType: 'application/json',
            temperature: 0.7,
            maxOutputTokens: 1024,
          },
        }),
        signal: AbortSignal.timeout(env.AI_TIMEOUT_MS),
      });
    } catch (_err) {
      throw Object.assign(new Error('gemini request failed'), { status: 0 });
    }
    if (!response.ok) {
      throw Object.assign(new Error('gemini error'), { status: response.status });
    }
    let json;
    try {
      json = await response.json();
    } catch (_err) {
      throw Object.assign(new Error('gemini bad body'), { status: 502 });
    }
    const parts = json && json.candidates && json.candidates[0] && json.candidates[0].content;
    return ((parts && parts.parts) || []).map((part) => part.text || '').join('');
  };
}

module.exports = { createGeminiClient };
