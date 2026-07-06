/**
 * api-server.js — جسر بين تطبيق Bridge والـ Chatterbox Space
 *
 * يطابق العقد الذي يتوقعه التطبيق تماماً:
 *   GET  /api/health                      → {backend_url_set, backend_ok}
 *   POST /api/voice/tts                   → ملف صوت WAV مباشرة (blob)
 *   POST /api/voice/tts?encoding=base64   → {ok: true, audio: "<base64>"}
 *
 * بدون أي تبعيات خارجية (Node 18+ فقط، fetch مدمج).
 *
 * التشغيل:
 *   INFERENCE_BASE_URL=https://abdo96-chatterbox.hf.space node api-server.js
 * متغيرات اختيارية:
 *   PORT=3000  HF_TOKEN=hf_xxx (لو الـ Space خاص)
 */

const http = require("http");

const SPACE = (process.env.INFERENCE_BASE_URL || "").replace(/\/+$/, "");
const PORT = process.env.PORT || 3000;
const HF_TOKEN = process.env.HF_TOKEN || null;

const hfHeaders = () =>
  HF_TOKEN ? { Authorization: `Bearer ${HF_TOKEN}` } : {};

/* ------------------------------------------------------------------ */
/* كشف اللغة: التطبيق يرسل النص فقط، و Chatterbox يحتاج language_id.  */
/* الأولوية لحقل lang لو أرسله التطبيق، وإلا نكشف من النص.            */
/* ------------------------------------------------------------------ */
function detectLang(text) {
  if (/[\u0600-\u06FF]/.test(text)) return "ar"; // عربي
  if (/[\u0900-\u097F]/.test(text)) return "hi"; // هندي (ديفاناغري)
  // 1) حروف فريدة لا تلتبس بين اللغات:
  if (/[ğıİĞŞş]/.test(text)) return "tr";
  if (/[ñ¿¡]/.test(text)) return "es";
  if (/[ß]/.test(text)) return "de";
  if (/[œ]/.test(text)) return "fr";
  // 2) كلمات شائعة (قبل الحروف المشتركة مثل ü/ö/é):
  const t = ` ${text.toLowerCase()} `;
  if (/ (bir|ve|bu|için|değil|güzel|nasıl) /.test(t)) return "tr";
  if (/ (el|la|los|las|es|está|pero|como) /.test(t)) return "es";
  if (/ (der|die|das|und|ist|nicht|ein) /.test(t)) return "de";
  if (/ (le|la|les|est|dans|pour|mais|vous) /.test(t)) return "fr";
  // 3) حروف مشتركة كملاذ أخير:
  if (/[äöü]/.test(text)) return "de";
  if (/[àâçêîôûëïù]/.test(text)) return "fr";
  return "en";
}

/* ------------------------------------------------------------------ */
/* استدعاء Gradio API على الـ Space (خطوتان: call ثم SSE)              */
/* ------------------------------------------------------------------ */
async function chatterboxTTS(text, lang) {
  // الخطوة 1: إرسال الطلب
  const callRes = await fetch(`${SPACE}/gradio_api/call/tts`, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...hfHeaders() },
    body: JSON.stringify({ data: [text, lang, 0.5, 0.5, null] }),
    signal: AbortSignal.timeout(30_000),
  });
  if (!callRes.ok) throw new Error(`Space call failed: HTTP ${callRes.status}`);
  const { event_id } = await callRes.json();
  if (!event_id) throw new Error("No event_id from Space");

  // الخطوة 2: انتظار النتيجة عبر SSE
  // مهلة طويلة: أول طلب بعد خمول يوقظ الـ Space ويحمّل النموذج (~دقيقة)
  const sseRes = await fetch(`${SPACE}/gradio_api/call/tts/${event_id}`, {
    headers: hfHeaders(),
    signal: AbortSignal.timeout(180_000),
  });
  if (!sseRes.ok) throw new Error(`Space result failed: HTTP ${sseRes.status}`);

  const raw = await sseRes.text();
  let event = "";
  let audioUrl = null;
  for (const line of raw.split("\n")) {
    if (line.startsWith("event:")) event = line.slice(6).trim();
    else if (line.startsWith("data:")) {
      const data = line.slice(5).trim();
      if (event === "error") throw new Error(`Space error: ${data}`);
      if (event === "complete") {
        const parsed = JSON.parse(data);
        audioUrl = parsed?.[0]?.url || null;
      }
    }
  }
  if (!audioUrl) throw new Error("No audio URL in Space response");

  // الخطوة 3: تنزيل ملف الصوت
  const audioRes = await fetch(audioUrl, {
    headers: hfHeaders(),
    signal: AbortSignal.timeout(60_000),
  });
  if (!audioRes.ok) throw new Error(`Audio download failed: HTTP ${audioRes.status}`);
  return Buffer.from(await audioRes.arrayBuffer());
}

/* ------------------------------------------------------------------ */
/* المسارات                                                            */
/* ------------------------------------------------------------------ */
async function handleHealth(res) {
  const payload = { backend_url_set: !!SPACE, backend_ok: false };
  if (SPACE) {
    try {
      const r = await fetch(`${SPACE}/`, {
        headers: hfHeaders(),
        signal: AbortSignal.timeout(10_000),
      });
      payload.backend_ok = r.ok;
    } catch { /* backend_ok يبقى false → التطبيق يعرض "GPU نايم" */ }
  }
  json(res, 200, payload);
}

async function handleTTS(req, res, url) {
  const body = await readJSON(req);
  const text = (body?.text || "").trim();
  if (!text) return json(res, 400, { ok: false, error: "text required" });
  if (text.length > 1000) return json(res, 400, { ok: false, error: "text too long" });

  const lang = body?.lang || detectLang(text);

  try {
    const audio = await chatterboxTTS(text, lang);

    if (url.searchParams.get("encoding") === "base64") {
      // مسار الموبايل (native): JSON مع base64
      return json(res, 200, { ok: true, audio: audio.toString("base64"), format: "wav" });
    }
    // مسار الويب: ملف صوت مباشر
    res.writeHead(200, {
      "Content-Type": "audio/wav",
      "Content-Length": audio.length,
      "Cache-Control": "no-store",
    });
    res.end(audio);
  } catch (e) {
    console.error("[tts]", e.message);
    json(res, 502, { ok: false, error: e.message });
  }
}

/* ------------------------------------------------------------------ */
/* الترجمة: مرّرها لأي مزود ترجمة. هنا مثال بسيط عبر متغير بيئة.        */
/* اضبط TRANSLATE_URL لخدمة ترجمة تقبل {text,from,to} وتعيد {translated} */
/* أو استبدل الجسم باستدعاء Google/DeepL/LibreTranslate.               */
/* ------------------------------------------------------------------ */
const TRANSLATE_URL = process.env.TRANSLATE_URL || "";

async function handleTranslate(req, res) {
  const body = await readJSON(req);
  const text = (body?.text || "").trim();
  const from = body?.from || "auto";
  const to = body?.to || "en";
  if (!text) return json(res, 400, { ok: false, error: "text required" });
  if (from === to) return json(res, 200, { ok: true, translated: text });

  try {
    // مثال باستخدام LibreTranslate-style API؛ عدّله لمزودك.
    if (!TRANSLATE_URL) {
      // احتياط: بدون مزود، أعِد النص كما هو مع تنبيه (لتعمل الواجهة أثناء التطوير)
      return json(res, 200, { ok: true, translated: text, note: "no TRANSLATE_URL set" });
    }
    const r = await fetch(TRANSLATE_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ q: text, source: from, target: to, format: "text" }),
      signal: AbortSignal.timeout(20_000),
    });
    if (!r.ok) throw new Error(`translate HTTP ${r.status}`);
    const data = await r.json();
    const translated = data.translatedText || data.translated || text;
    json(res, 200, { ok: true, translated });
  } catch (e) {
    console.error("[translate]", e.message);
    json(res, 502, { ok: false, error: e.message });
  }
}

/* ------------------------------------------------------------------ */
/* التفريغ الصوتي (STT): يستقبل ملف multipart ويعيد النص.              */
/* مرّره لـ Whisper/ElevenLabs Scribe. هنا هيكل جاهز للربط.           */
/* اضبط STT_URL لخدمة تقبل الملف الصوتي وتعيد النص.                   */
/* ------------------------------------------------------------------ */
const STT_URL = process.env.STT_URL || "";

async function handleSTT(req, res) {
  // ملاحظة: هذا السيرفر بلا تبعيات، لذا نقرأ الجسم الخام.
  // للتبسيط نتوقع أن يرسل التطبيق الصوت، ونمرّره كما هو لخدمة STT.
  // في الإنتاج استخدم مكتبة multipart (مثل busboy) لتحليل الملف بدقة.
  if (!STT_URL) {
    return json(res, 200, { ok: true, text: "", note: "no STT_URL set — configure it" });
  }
  try {
    const chunks = [];
    for await (const c of req) chunks.push(c);
    const buf = Buffer.concat(chunks);
    const r = await fetch(STT_URL, {
      method: "POST",
      headers: { "Content-Type": req.headers["content-type"] || "application/octet-stream" },
      body: buf,
      signal: AbortSignal.timeout(60_000),
    });
    if (!r.ok) throw new Error(`stt HTTP ${r.status}`);
    const data = await r.json();
    json(res, 200, { ok: true, text: (data.text || "").trim() });
  } catch (e) {
    console.error("[stt]", e.message);
    json(res, 502, { ok: false, error: e.message });
  }
}

/* ------------------------------------------------------------------ */
/* أدوات مساعدة + السيرفر                                              */
/* ------------------------------------------------------------------ */
function json(res, code, obj) {
  const s = JSON.stringify(obj);
  res.writeHead(code, { "Content-Type": "application/json; charset=utf-8" });
  res.end(s);
}

function readJSON(req) {
  return new Promise((resolve) => {
    let data = "";
    req.on("data", (c) => { data += c; if (data.length > 100_000) req.destroy(); });
    req.on("end", () => { try { resolve(JSON.parse(data)); } catch { resolve(null); } });
    req.on("error", () => resolve(null));
  });
}

const server = http.createServer(async (req, res) => {
  // CORS للويب
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  if (req.method === "OPTIONS") { res.writeHead(204); return res.end(); }

  const url = new URL(req.url, `http://${req.headers.host}`);
  try {
    if (url.pathname === "/api/health" && req.method === "GET") return await handleHealth(res);
    if (url.pathname === "/api/voice/tts" && req.method === "POST") return await handleTTS(req, res, url);
    if (url.pathname === "/api/translate" && req.method === "POST") return await handleTranslate(req, res);
    if (url.pathname === "/api/voice/stt" && req.method === "POST") return await handleSTT(req, res);
    json(res, 404, { error: "not found" });
  } catch (e) {
    console.error("[server]", e);
    json(res, 500, { error: "internal" });
  }
});

server.listen(PORT, () => {
  console.log(`🎙️ TTS bridge on :${PORT}`);
  console.log(`   Space: ${SPACE || "⚠️ INFERENCE_BASE_URL غير مضبوط!"}`);
});
