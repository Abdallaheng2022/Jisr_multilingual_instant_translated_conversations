-- ═══════════════════════════════════════════════
-- الرصيد اليومي على الخادم (يتبع الحساب لا الجهاز)
-- شغّل هذا في Supabase → SQL Editor
-- ═══════════════════════════════════════════════

-- أعمدة تتبّع الاستهلاك اليومي
alter table users add column if not exists quota_day date;
alter table users add column if not exists used_today int default 0;
alter table users add column if not exists voice_notes_today int default 0;

-- ═══════════════════════════════════════════════
-- دالة الخصم الآمنة (تتحقق من اليوم وتخصم ذرّياً)
-- تمنع التلاعب: الحساب على الخادم لا الجهاز
-- ═══════════════════════════════════════════════

create or replace function consume_quota(
  p_kind text,          -- 'translate' أو 'voice_note'
  p_limit int           -- الحد اليومي (3)
)
returns json
language plpgsql
security definer
as $$
declare
  v_uid uuid := auth.uid();
  v_today date := current_date;
  v_row users%rowtype;
  v_used int;
  v_subscribed boolean;
begin
  if v_uid is null then
    return json_build_object('ok', false, 'error', 'not_authenticated');
  end if;

  select * into v_row from users where id = v_uid for update;
  if not found then
    return json_build_object('ok', false, 'error', 'no_user');
  end if;

  v_subscribed := coalesce(v_row.subscribed, false);

  -- المشتركون: بلا حدود
  if v_subscribed then
    return json_build_object('ok', true, 'remaining', 999, 'subscribed', true);
  end if;

  -- يوم جديد → صفّر العدّادات
  if v_row.quota_day is distinct from v_today then
    update users
      set quota_day = v_today, used_today = 0, voice_notes_today = 0
      where id = v_uid;
    v_row.used_today := 0;
    v_row.voice_notes_today := 0;
  end if;

  v_used := case p_kind
    when 'voice_note' then coalesce(v_row.voice_notes_today, 0)
    else coalesce(v_row.used_today, 0)
  end;

  -- نفد الرصيد
  if v_used >= p_limit then
    return json_build_object('ok', false, 'error', 'quota_exceeded',
                             'remaining', 0, 'subscribed', false);
  end if;

  -- اخصم
  if p_kind = 'voice_note' then
    update users set voice_notes_today = v_used + 1, quota_day = v_today
      where id = v_uid;
  else
    update users set used_today = v_used + 1, quota_day = v_today
      where id = v_uid;
  end if;

  return json_build_object('ok', true,
                           'remaining', p_limit - (v_used + 1),
                           'subscribed', false);
end;
$$;

-- ═══════════════════════════════════════════════
-- دالة قراءة الرصيد الحالي (بلا خصم)
-- ═══════════════════════════════════════════════

create or replace function get_quota()
returns json
language plpgsql
security definer
as $$
declare
  v_uid uuid := auth.uid();
  v_today date := current_date;
  v_row users%rowtype;
begin
  if v_uid is null then
    return json_build_object('ok', false);
  end if;

  select * into v_row from users where id = v_uid;
  if not found then
    return json_build_object('ok', false);
  end if;

  -- يوم جديد → الرصيد كامل (بلا حاجة لتحديث الآن)
  if v_row.quota_day is distinct from v_today then
    return json_build_object('ok', true, 'used_today', 0,
                             'voice_notes_today', 0,
                             'subscribed', coalesce(v_row.subscribed, false));
  end if;

  return json_build_object(
    'ok', true,
    'used_today', coalesce(v_row.used_today, 0),
    'voice_notes_today', coalesce(v_row.voice_notes_today, 0),
    'subscribed', coalesce(v_row.subscribed, false)
  );
end;
$$;

-- السماح للمستخدمين المسجّلين باستدعاء الدالتين
grant execute on function consume_quota(text, int) to authenticated;
grant execute on function get_quota() to authenticated;
