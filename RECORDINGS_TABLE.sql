-- ═══════════════════════════════════════════════
-- جدول التسجيلات + الإذن (بيانات العملاء)
-- شغّل هذا في Supabase → SQL Editor
-- ═══════════════════════════════════════════════

create table if not exists recordings (
  id bigint generated always as identity primary key,
  user_id uuid references users(id) on delete cascade,

  -- المحتوى
  original_text text,           -- النص المُفرّغ (قبل التصحيح)
  corrected_text text,          -- النص بعد تصحيح المستخدم
  translated_text text,         -- الترجمة
  was_corrected boolean default false,

  -- اللغات
  source_lang text,
  target_lang text,

  -- الصوت
  audio_url text,               -- الصوت الأصلي
  cloned_audio_url text,        -- الصوت المُستنسخ
  audio_duration real,

  -- الإذن (إلزامي — لا تُحفظ بيانات بلا موافقة)
  consent boolean default false,

  -- السياق
  section text,                 -- 'translate' | 'whatsapp' | 'room'
  created_at timestamptz default now()
);

-- إن كان الجدول موجوداً مسبقاً، أضف عمود الإذن
alter table recordings add column if not exists consent boolean default false;

create index if not exists recordings_user_idx on recordings(user_id, created_at desc);
create index if not exists recordings_training_idx on recordings(consent, was_corrected, source_lang);

alter table recordings enable row level security;

drop policy if exists "own_recordings" on recordings;
create policy "own_recordings" on recordings
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

alter publication supabase_realtime add table recordings;

-- ═══════════════════════════════════════════════
-- استعلامات: هل جمعت ما يكفي للتدريب؟
-- ═══════════════════════════════════════════════

-- كم عينة تدريب صالحة لكل لغة؟ (بإذن + مصححة + لها صوت)
-- select source_lang,
--        count(*) as samples,
--        count(distinct user_id) as users
-- from recordings
-- where consent = true
--   and was_corrected = true
--   and audio_url is not null
-- group by source_lang
-- order by samples desc;

-- التصحيحات المعتمدة (اجتازت معايير الجودة)
-- select language, count(*) as approved
-- from corrections
-- where status = 'approved'
-- group by language;

-- ═══════════════════════════════════════════════
-- عتبة التدريب المقترحة:
--   • 1,000+ عينة للغة/لهجة واحدة = بداية معقولة
--   • 5,000+ عينة = تحسّن ملموس
--   • من 50+ مستخدماً مختلفاً = تنوّع صوتي جيد
-- ═══════════════════════════════════════════════

-- ملاحظة: أنشئ bucket في Storage باسم: recordings (public)
