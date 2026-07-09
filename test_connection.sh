#!/usr/bin/env bash
# test_connection.sh — اختبار الاتصال بالـ Space خطوة بخطوة
# الاستخدام:  bash test_connection.sh
#
# يختبر كل مرحلة على حدة ويطبع النتيجة بوضوح، فتعرف أين المشكلة بالضبط.

SPACE="https://abdo96-chatterbox.hf.space"

echo "═══════════════════════════════════════════"
echo "  اختبار الاتصال بـ: $SPACE"
echo "═══════════════════════════════════════════"
echo ""

# ── 1) هل الـ Space حيّ أصلاً؟ ──
echo "【1】 فحص أن الـ Space يستجيب..."
CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 20 "$SPACE/")
if [ "$CODE" = "200" ]; then
  echo "    ✅ الـ Space حيّ (HTTP 200)"
else
  echo "    ❌ الـ Space لا يستجيب (HTTP $CODE)"
  echo "    → المشكلة: الـ Space نائم أو متوقف. افتحه في المتصفح لإيقاظه."
  exit 1
fi
echo ""

# ── 2) هل endpoint الترجمة موجود؟ (الأبسط، بلا ملفات) ──
echo "【2】 اختبار الترجمة (أبسط خدمة)..."
RESP=$(curl -s --max-time 30 -X POST "$SPACE/gradio_api/call/translate" \
  -H "Content-Type: application/json" \
  -d '{"data":["مرحبا","العربية (ar)","English (en)"]}')
echo "    الرد: $RESP"
EVENT=$(echo "$RESP" | grep -o '"event_id":"[^"]*"' | cut -d'"' -f4)
if [ -n "$EVENT" ]; then
  echo "    ✅ endpoint الترجمة يعمل (event_id: $EVENT)"
  echo "    → جارٍ جلب النتيجة (قد يأخذ دقيقة لأول مرة)..."
  sleep 2
  RESULT=$(curl -s --max-time 120 "$SPACE/gradio_api/call/translate/$EVENT")
  echo "    النتيجة: $RESULT"
else
  echo "    ❌ endpoint الترجمة لم يُرجع event_id"
  echo "    → المشكلة: app.py الموحّد غير مرفوع، أو الـ Space يُعيد البناء."
  exit 1
fi
echo ""

# ── 3) هل مسار رفع الملفات يعمل؟ (المهم لـ stt) ──
echo "【3】 اختبار رفع ملف (المطلوب للتفريغ)..."
# أنشئ ملف wav صغير صامت للاختبار
TESTWAV="/tmp/test_silence.wav"
# رأس WAV بسيط + ثانية صمت (16kHz mono)
python3 -c "
import wave, struct
w = wave.open('$TESTWAV','w')
w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000)
w.writeframes(b'\x00\x00' * 16000)
w.close()
print('    أُنشئ ملف اختبار:', '$TESTWAV')
" 2>/dev/null || echo "    (تعذّر إنشاء ملف الاختبار — تخطّي)"

if [ -f "$TESTWAV" ]; then
  UP=$(curl -s --max-time 30 -X POST "$SPACE/gradio_api/upload" \
    -F "files=@$TESTWAV")
  echo "    رد الرفع: $UP"
  if echo "$UP" | grep -q "\["; then
    echo "    ✅ رفع الملفات يعمل"
  else
    echo "    ⚠️ رد غير متوقع من الرفع"
  fi
fi
echo ""

echo "═══════════════════════════════════════════"
echo "  الخلاصة:"
echo "  إن نجحت الخطوات 1 و 2 و 3 → الـ Space جاهز،"
echo "  والتطبيق يجب أن يعمل (بعد بناء APK بالكود الأخير)."
echo "  إن فشلت خطوة → المشكلة عندها بالضبط."
echo "═══════════════════════════════════════════"
