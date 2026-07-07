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
/* كل الخدمات تعمل على نفس الـ Space (SPACE = INFERENCE_BASE_URL):        */
/*   /tts /translate /stt — لا حاجة لمتغيرات منفصلة.                       */
/* ------------------------------------------------------------------ */

/**
 * مُنادٍ عام لأي endpoint في Gradio (نمط الخطوتين: call ثم SSE).
 * يعيد أول عنصر من مصفوفة النتيجة (نص أو كائن ملف {url}).
 */
async function callGradio(endpoint, dataArray, resultTimeoutMs = 180_000) {
  const callRes = await fetch(`${SPACE}/gradio_api/call/${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...hfHeaders() },
    body: JSON.stringify({ data: dataArray }),
    signal: AbortSignal.timeout(30_000),
  });
  if (callRes.status === 404) {
    throw new Error(
      `endpoint '${endpoint}' غير موجود على الـ Space (HTTP 404). ` +
      `تأكد أنك رفعت app.py الموحّد الذي يحتوي دوال tts/translate/stt.`
    );
  }
  if (!callRes.ok) throw new Error(`${endpoint} call failed: HTTP ${callRes.status}`);
  const { event_id } = await callRes.json();
  if (!event_id) throw new Error(`No event_id from ${endpoint}`);

  const sseRes = await fetch(`${SPACE}/gradio_api/call/${endpoint}/${event_id}`, {
    headers: hfHeaders(),
    signal: AbortSignal.timeout(resultTimeoutMs),
  });
  if (!sseRes.ok) throw new Error(`${endpoint} result failed: HTTP ${sseRes.status}`);

  const raw = await sseRes.text();
  let event = "", result = null;
  for (const line of raw.split("\n")) {
    if (line.startsWith("event:")) event = line.slice(6).trim();
    else if (line.startsWith("data:")) {
      const data = line.slice(5).trim();
      if (event === "error") throw new Error(`${endpoint} error: ${data}`);
      if (event === "complete") {
        const parsed = JSON.parse(data);
        result = Array.isArray(parsed) ? parsed[0] : parsed;
      }
    }
  }
  return result;
}

async function handleTranslate(req, res) {
  const body = await readJSON(req);
  const text = (body?.text || "").trim();
  const from = body?.from || "auto";
  const to = body?.to || "en";
  if (!text) return json(res, 400, { ok: false, error: "text required" });
  if (from === to) return json(res, 200, { ok: true, translated: text });

  try {
    // ينادي endpoint الترجمة على الـ Space: translate(text, source, target)
    const translated = await callGradio("translate", [text, from, to], 120_000);
    json(res, 200, { ok: true, translated: (translated || text) });
  } catch (e) {
    console.error("[translate]", e.message);
    json(res, 502, { ok: false, error: e.message });
  }
}

/* ------------------------------------------------------------------ */
/* التفريغ الصوتي (STT): يستقبل ملف multipart ويعيد النص.              */
/* مرّره لـ Whisper/ElevenLabs Scribe. هنا هيكل جاهز للربط.           */
/* التفريغ الصوتي: يرفع الملف لـ Gradio ثم ينادي endpoint الخاص بـ stt. */
/* ------------------------------------------------------------------ */

/** يرفع ملفاً لـ Gradio ويعيد مرجع الملف الذي تقبله الدالة. */
async function uploadToGradio(buffer, filename, contentType) {
  const boundary = "----jisr" + Date.now();
  const head = Buffer.from(
    `--${boundary}\r\n` +
    `Content-Disposition: form-data; name="files"; filename="${filename}"\r\n` +
    `Content-Type: ${contentType}\r\n\r\n`
  );
  const tail = Buffer.from(`\r\n--${boundary}--\r\n`);
  const body = Buffer.concat([head, buffer, tail]);

  // مسار الرفع في Gradio هو /upload (وأيضاً /gradio_api/upload على Spaces).
  // نجرّب /gradio_api/upload أولاً ثم /upload كبديل.
  let r = await fetch(`${SPACE}/gradio_api/upload`, {
    method: "POST",
    headers: { "Content-Type": `multipart/form-data; boundary=${boundary}`, ...hfHeaders() },
    body,
    signal: AbortSignal.timeout(60_000),
  });
  if (r.status === 404) {
    r = await fetch(`${SPACE}/upload`, {
      method: "POST",
      headers: { "Content-Type": `multipart/form-data; boundary=${boundary}`, ...hfHeaders() },
      body,
      signal: AbortSignal.timeout(60_000),
    });
  }
  if (!r.ok) throw new Error(`upload failed: HTTP ${r.status}`);
  const paths = await r.json(); // قائمة مسارات على الخادم
  const p = Array.isArray(paths) ? paths[0] : paths;
  // شكل كائن الملف كما يتوقعه Gradio (url = null لأن الملف مرفوع بالفعل)
  return { path: p, orig_name: filename, url: null, meta: { _type: "gradio.FileData" } };
}

async function handleSTT(req, res) {
  try {
    const chunks = [];
    for await (const c of req) chunks.push(c);
    const buf = Buffer.concat(chunks);
    if (buf.length === 0) return json(res, 400, { ok: false, error: "empty audio" });

    // لغة اختيارية من ترويسة مخصّصة
    const lang = req.headers["x-lang"] || "";
    const ct = req.headers["content-type"] || "audio/m4a";
    const ext = ct.includes("wav") ? "wav" : ct.includes("mp4") ? "mp4" : "m4a";

    const fileRef = await uploadToGradio(buf, `audio.${ext}`, ct);
    const text = await callGradio("stt", [fileRef, lang], 120_000);
    json(res, 200, { ok: true, text: (text || "").trim() });
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
