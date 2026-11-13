-- KalamAI initial schema. Run in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.proficiency_levels (
 id uuid primary key default gen_random_uuid(), code text not null unique, name_id text not null, name_ar text not null,
 description text not null default '', sort_order integer not null unique, learning_objectives jsonb not null default '[]'::jsonb,
 is_active boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade, display_name text not null default 'Pelajar KalamAI',
 preferred_language text not null default 'id' check (preferred_language in ('id','ar')),
 current_level_id uuid references public.proficiency_levels(id) on delete set null,
 learning_preferences jsonb not null default '{"correction_language":"id","practice_mode":"guided","daily_target_minutes":10}'::jsonb,
 role text not null default 'learner' check (role in ('learner','admin')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.scenarios (
 id uuid primary key default gen_random_uuid(), slug text not null unique, title_id text not null, title_ar text not null,
 description text not null default '', minimum_level_id uuid references public.proficiency_levels(id) on delete set null,
 learning_objectives jsonb not null default '[]'::jsonb, vocabulary_targets jsonb not null default '[]'::jsonb,
 suggested_prompts jsonb not null default '[]'::jsonb, evaluation_criteria jsonb not null default '[]'::jsonb,
 opening_message text not null default 'مرحبًا! لنتدرّب معًا. عرّفني بنفسك باللغة العربية.',
 is_published boolean not null default false, created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.conversation_sessions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 scenario_id uuid references public.scenarios(id) on delete set null,
 interaction_mode text not null default 'text' check (interaction_mode in ('text','voice')),
 status text not null default 'active' check (status in ('active','completed','abandoned')),
 started_at timestamptz not null default now(), completed_at timestamptz
);
create table if not exists public.conversation_messages (
 id uuid primary key default gen_random_uuid(), session_id uuid not null references public.conversation_sessions(id) on delete cascade,
 role text not null check (role in ('user','assistant')), content text not null check (length(content) <= 8000),
 input_type text not null default 'text' check (input_type in ('text','audio')), created_at timestamptz not null default now()
);
create table if not exists public.speech_transcriptions (
 id uuid primary key default gen_random_uuid(), session_id uuid references public.conversation_sessions(id) on delete cascade,
 message_id uuid references public.conversation_messages(id) on delete set null, transcript text not null default '', corrected_transcript text,
 transcription_status text not null default 'pending' check (transcription_status in ('pending','completed','failed')), created_at timestamptz not null default now()
);
create table if not exists public.grammar_corrections (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 session_id uuid references public.conversation_sessions(id) on delete set null, message_id uuid references public.conversation_messages(id) on delete set null,
 original_text text not null, corrected_text text not null, natural_alternative text,
 overall_assessment text not null check (overall_assessment in ('correct','needs_correction','uncertain')),
 structured_feedback jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create table if not exists public.assessment_results (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 session_id uuid references public.conversation_sessions(id) on delete set null, level_id uuid references public.proficiency_levels(id) on delete set null,
 rubric_scores jsonb not null default '{}'::jsonb, overall_score numeric, evaluator_type text not null default 'ai_estimate',
 confidence_notes text not null default '', created_at timestamptz not null default now()
);
create table if not exists public.vocabulary_items (
 id uuid primary key default gen_random_uuid(), arabic_text text not null unique, indonesian_meaning text not null,
 example_sentence text not null default '', difficulty_level_id uuid references public.proficiency_levels(id) on delete set null,
 is_published boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.user_vocabulary (
 user_id uuid not null references auth.users(id) on delete cascade,
 vocabulary_item_id uuid not null references public.vocabulary_items(id) on delete cascade,
 review_status text not null default 'new' check (review_status in ('new','learning','mastered')),
 created_at timestamptz not null default now(), primary key (user_id,vocabulary_item_id)
);
create table if not exists public.learning_activities (
 id uuid primary key default gen_random_uuid(), title text not null, activity_type text not null,
 level_id uuid references public.proficiency_levels(id) on delete set null, content jsonb not null default '{}'::jsonb,
 is_published boolean not null default false, created_at timestamptz not null default now()
);
create table if not exists public.activity_completions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 activity_id uuid not null references public.learning_activities(id) on delete cascade,
 result jsonb not null default '{}'::jsonb, completed_at timestamptz not null default now(), unique(user_id,activity_id)
);
create table if not exists public.consent_records (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 consent_type text not null, granted boolean not null, policy_version text not null, created_at timestamptz not null default now()
);
create table if not exists public.language_exchange_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade, languages jsonb not null default '["id","ar"]'::jsonb,
 proficiency_level_id uuid references public.proficiency_levels(id) on delete set null, availability jsonb not null default '[]'::jsonb,
 visibility text not null default 'private' check (visibility in ('private','visible')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.language_exchange_sessions (
 id uuid primary key default gen_random_uuid(), initiator_user_id uuid not null references auth.users(id) on delete cascade,
 partner_user_id uuid not null references auth.users(id) on delete cascade, scheduled_at timestamptz,
 status text not null default 'requested' check (status in ('requested','accepted','cancelled','completed')),
 created_at timestamptz not null default now(), check (initiator_user_id <> partner_user_id)
);

-- Shared database-backed rate limiter. Only the server's service-role client can use it.
create table if not exists public.api_rate_limits (key text primary key, window_started_at timestamptz not null, hits integer not null default 0);
alter table public.api_rate_limits enable row level security;
revoke all on public.api_rate_limits from anon, authenticated;
grant all on public.api_rate_limits to service_role;
create or replace function public.consume_rate_limit(p_key text,p_window_seconds integer,p_limit integer)
returns boolean language plpgsql security definer set search_path=public as $$
declare current_hits integer; cutoff timestamptz := now() - make_interval(secs => greatest(p_window_seconds,1));
begin
 insert into public.api_rate_limits(key,window_started_at,hits) values(p_key,now(),1)
 on conflict(key) do update set hits=case when public.api_rate_limits.window_started_at<cutoff then 1 else public.api_rate_limits.hits+1 end,
 window_started_at=case when public.api_rate_limits.window_started_at<cutoff then now() else public.api_rate_limits.window_started_at end
 returning hits into current_hits;
 return current_hits <= greatest(p_limit,1);
end; $$;
revoke all on function public.consume_rate_limit(text,integer,integer) from public,anon,authenticated;
grant execute on function public.consume_rate_limit(text,integer,integer) to service_role;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='admin');
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon,authenticated;
create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end; $$;
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,display_name,current_level_id) values(new.id,coalesce(nullif(trim(new.raw_user_meta_data->>'display_name'),''),'Pelajar KalamAI'),(select id from public.proficiency_levels where code='L1' limit 1)) on conflict(id) do nothing;
 return new;
end; $$;

create index if not exists idx_sessions_user_started on public.conversation_sessions(user_id,started_at desc);
create index if not exists idx_messages_session_created on public.conversation_messages(session_id,created_at);
create index if not exists idx_corrections_user_created on public.grammar_corrections(user_id,created_at desc);
create index if not exists idx_user_vocab_user on public.user_vocabulary(user_id);

alter table public.proficiency_levels enable row level security;
alter table public.profiles enable row level security;
alter table public.scenarios enable row level security;
alter table public.conversation_sessions enable row level security;
alter table public.conversation_messages enable row level security;
alter table public.speech_transcriptions enable row level security;
alter table public.grammar_corrections enable row level security;
alter table public.assessment_results enable row level security;
alter table public.vocabulary_items enable row level security;
alter table public.user_vocabulary enable row level security;
alter table public.learning_activities enable row level security;
alter table public.activity_completions enable row level security;
alter table public.consent_records enable row level security;
alter table public.language_exchange_profiles enable row level security;
alter table public.language_exchange_sessions enable row level security;

-- Drop/recreate app policies to make rerunning the migration safer.
drop policy if exists levels_read_active on public.proficiency_levels;
create policy levels_read_active on public.proficiency_levels for select to anon,authenticated using(is_active=true or public.is_admin());
drop policy if exists profiles_read_own_or_admin on public.profiles;
create policy profiles_read_own_or_admin on public.profiles for select to authenticated using(id=auth.uid() or public.is_admin());
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
revoke all on public.profiles from anon,authenticated;
grant select on public.profiles to authenticated;
grant update(display_name,preferred_language,learning_preferences,updated_at) on public.profiles to authenticated;

drop policy if exists scenarios_read_published on public.scenarios;
create policy scenarios_read_published on public.scenarios for select to anon,authenticated using(is_published=true or public.is_admin());
drop policy if exists scenarios_admin_insert on public.scenarios;
create policy scenarios_admin_insert on public.scenarios for insert to authenticated with check(public.is_admin());
drop policy if exists scenarios_admin_update on public.scenarios;
create policy scenarios_admin_update on public.scenarios for update to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists scenarios_admin_delete on public.scenarios;
create policy scenarios_admin_delete on public.scenarios for delete to authenticated using(public.is_admin());

drop policy if exists sessions_read_own on public.conversation_sessions;
create policy sessions_read_own on public.conversation_sessions for select to authenticated using(user_id=auth.uid());
drop policy if exists sessions_insert_own on public.conversation_sessions;
create policy sessions_insert_own on public.conversation_sessions for insert to authenticated with check(user_id=auth.uid() and (scenario_id is null or exists(select 1 from public.scenarios sc where sc.id=scenario_id and sc.is_published=true)));
drop policy if exists sessions_update_own on public.conversation_sessions;
create policy sessions_update_own on public.conversation_sessions for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
drop policy if exists sessions_delete_own on public.conversation_sessions;
create policy sessions_delete_own on public.conversation_sessions for delete to authenticated using(user_id=auth.uid());
drop policy if exists messages_read_owned_session on public.conversation_messages;
create policy messages_read_owned_session on public.conversation_messages for select to authenticated using(exists(select 1 from public.conversation_sessions s where s.id=session_id and s.user_id=auth.uid()));
drop policy if exists messages_insert_owned_session on public.conversation_messages;
create policy messages_insert_owned_session on public.conversation_messages for insert to authenticated with check(exists(select 1 from public.conversation_sessions s where s.id=session_id and s.user_id=auth.uid()));
drop policy if exists transcriptions_read_owned_session on public.speech_transcriptions;
create policy transcriptions_read_owned_session on public.speech_transcriptions for select to authenticated using(exists(select 1 from public.conversation_sessions s where s.id=session_id and s.user_id=auth.uid()));
drop policy if exists transcriptions_insert_owned_session on public.speech_transcriptions;
create policy transcriptions_insert_owned_session on public.speech_transcriptions for insert to authenticated with check(exists(select 1 from public.conversation_sessions s where s.id=session_id and s.user_id=auth.uid()));
drop policy if exists corrections_read_own on public.grammar_corrections;
create policy corrections_read_own on public.grammar_corrections for select to authenticated using(user_id=auth.uid());
drop policy if exists corrections_insert_own on public.grammar_corrections;
create policy corrections_insert_own on public.grammar_corrections for insert to authenticated with check(user_id=auth.uid() and (session_id is null or exists(select 1 from public.conversation_sessions s where s.id=session_id and s.user_id=auth.uid())));
drop policy if exists corrections_delete_own on public.grammar_corrections;
create policy corrections_delete_own on public.grammar_corrections for delete to authenticated using(user_id=auth.uid());
drop policy if exists assessments_read_own on public.assessment_results;
create policy assessments_read_own on public.assessment_results for select to authenticated using(user_id=auth.uid());
drop policy if exists assessments_insert_own on public.assessment_results;
create policy assessments_insert_own on public.assessment_results for insert to authenticated with check(user_id=auth.uid());
drop policy if exists vocabulary_read_published on public.vocabulary_items;
create policy vocabulary_read_published on public.vocabulary_items for select to anon,authenticated using(is_published=true or public.is_admin());
drop policy if exists user_vocabulary_read_own on public.user_vocabulary;
create policy user_vocabulary_read_own on public.user_vocabulary for select to authenticated using(user_id=auth.uid());
drop policy if exists user_vocabulary_insert_own on public.user_vocabulary;
create policy user_vocabulary_insert_own on public.user_vocabulary for insert to authenticated with check(user_id=auth.uid());
drop policy if exists user_vocabulary_update_own on public.user_vocabulary;
create policy user_vocabulary_update_own on public.user_vocabulary for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
drop policy if exists user_vocabulary_delete_own on public.user_vocabulary;
create policy user_vocabulary_delete_own on public.user_vocabulary for delete to authenticated using(user_id=auth.uid());
drop policy if exists activities_read_published on public.learning_activities;
create policy activities_read_published on public.learning_activities for select to authenticated using(is_published=true or public.is_admin());
drop policy if exists completions_read_own on public.activity_completions;
create policy completions_read_own on public.activity_completions for select to authenticated using(user_id=auth.uid());
drop policy if exists completions_insert_own on public.activity_completions;
create policy completions_insert_own on public.activity_completions for insert to authenticated with check(user_id=auth.uid());
drop policy if exists consent_read_own on public.consent_records;
create policy consent_read_own on public.consent_records for select to authenticated using(user_id=auth.uid());
drop policy if exists consent_insert_own on public.consent_records;
create policy consent_insert_own on public.consent_records for insert to authenticated with check(user_id=auth.uid());
drop policy if exists exchange_profile_read_own on public.language_exchange_profiles;
create policy exchange_profile_read_own on public.language_exchange_profiles for select to authenticated using(user_id=auth.uid());
drop policy if exists exchange_profile_insert_own on public.language_exchange_profiles;
create policy exchange_profile_insert_own on public.language_exchange_profiles for insert to authenticated with check(user_id=auth.uid());
drop policy if exists exchange_profile_update_own on public.language_exchange_profiles;
create policy exchange_profile_update_own on public.language_exchange_profiles for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
drop policy if exists exchange_sessions_read_participant on public.language_exchange_sessions;
create policy exchange_sessions_read_participant on public.language_exchange_sessions for select to authenticated using(initiator_user_id=auth.uid() or partner_user_id=auth.uid());
drop policy if exists exchange_sessions_insert_initiator on public.language_exchange_sessions;
create policy exchange_sessions_insert_initiator on public.language_exchange_sessions for insert to authenticated with check(initiator_user_id=auth.uid());
drop policy if exists exchange_sessions_update_participant on public.language_exchange_sessions;
create policy exchange_sessions_update_participant on public.language_exchange_sessions for update to authenticated using(initiator_user_id=auth.uid() or partner_user_id=auth.uid()) with check(initiator_user_id=auth.uid() or partner_user_id=auth.uid());

grant select on public.proficiency_levels,public.scenarios,public.vocabulary_items to anon,authenticated;
grant select,insert,delete on public.conversation_sessions to authenticated;
revoke update on public.conversation_sessions from authenticated;
grant update(status,completed_at) on public.conversation_sessions to authenticated;
grant select,insert on public.conversation_messages,public.speech_transcriptions to authenticated;
grant select,insert,delete on public.grammar_corrections to authenticated;
grant select,insert on public.assessment_results to authenticated;
grant select,insert,update,delete on public.user_vocabulary to authenticated;
grant select on public.learning_activities to authenticated;
grant select,insert on public.activity_completions,public.consent_records to authenticated;
-- Language exchange is not active in this MVP; keep future-phase tables inaccessible to browser roles.
revoke all on public.language_exchange_profiles,public.language_exchange_sessions from anon,authenticated;
grant insert,update,delete on public.scenarios to authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles for each row execute procedure public.set_updated_at();
drop trigger if exists scenarios_set_updated_at on public.scenarios;
create trigger scenarios_set_updated_at before update on public.scenarios for each row execute procedure public.set_updated_at();
drop trigger if exists exchange_profiles_set_updated_at on public.language_exchange_profiles;
create trigger exchange_profiles_set_updated_at before update on public.language_exchange_profiles for each row execute procedure public.set_updated_at();

insert into public.proficiency_levels(code,name_id,name_ar,description,sort_order,learning_objectives) values
('L1','Pemula','مبتدئ','Sapaan, perkenalan, kosakata dasar, dan kalimat sederhana.',1,'["Memberi salam","Memperkenalkan diri","Menyusun kalimat sederhana"]'),
('L2','Dasar','أساسي','Rutinitas, keluarga, makanan, lokasi, dan pertanyaan umum.',2,'["Menceritakan rutinitas","Mengajukan pertanyaan umum","Mendeskripsikan lokasi"]'),
('L3','Menengah','متوسط','Menceritakan pengalaman, menyampaikan pendapat, dan percakapan singkat.',3,'["Menceritakan pengalaman","Menyampaikan pendapat","Menjaga alur percakapan"]'),
('L4','Menengah Atas','فوق المتوسط','Diskusi panjang, penjelasan, sebab-akibat, dan struktur lebih kompleks.',4,'["Menjelaskan sebab-akibat","Menyampaikan argumen","Mengembangkan jawaban"]'),
('L5','Lanjutan','متقدم','Presentasi, debat, argumen, dan ekspresi bernuansa.',5,'["Menyampaikan presentasi","Membangun argumen","Menanggapi pendapat"]'),
('L6','Mahir','متقدم جدًا','Diskusi akademik, ekspresi presisi, dan pilihan retoris.',6,'["Berdiskusi secara akademik","Memilih register yang tepat","Mengungkapkan nuansa makna"]')
on conflict(code) do update set name_id=excluded.name_id,name_ar=excluded.name_ar,description=excluded.description,sort_order=excluded.sort_order,learning_objectives=excluded.learning_objectives,is_active=true;

insert into public.scenarios(slug,title_id,title_ar,description,minimum_level_id,learning_objectives,vocabulary_targets,suggested_prompts,evaluation_criteria,opening_message,is_published) values
('introductions','Perkenalan','التعارف','Berlatih memperkenalkan diri, asal, studi, dan minat.',(select id from public.proficiency_levels where code='L1'),'["Memperkenalkan nama dan asal","Menjawab pertanyaan sederhana"]','["اسم","بلد","جامعة","هواية"]','["ما اسمك؟","من أين أنت؟","ماذا تدرس؟"]','["Kejelasan informasi","Kalimat dasar","Respons relevan"]','مرحبًا! لنتدرّب على التعارف. ما اسمك؟ عرّفني بنفسك باللغة العربية.',true),
('restaurant','Di Restoran','في المطعم','Memesan makanan dan minuman dengan ungkapan yang sopan.',(select id from public.proficiency_levels where code='L2'),'["Memesan makanan","Menanyakan harga","Mengucapkan terima kasih"]','["قائمة الطعام","ماء","أريد","الحساب"]','["ماذا تريد أن تطلب؟","هل تريد مشروبًا؟"]','["Kosakata makanan","Permintaan sopan","Respons sesuai konteks"]','أهلًا بك في المطعم. تفضّل، ماذا تريد أن تطلب؟',true),
('market','Di Pasar','في السوق','Berlatih bertanya harga, jumlah, dan pilihan barang.',(select id from public.proficiency_levels where code='L2'),'["Menanyakan harga","Menyebut jumlah","Melakukan transaksi sederhana"]','["سعر","كم","أريد","كيلو"]','["كم سعر هذا؟","كم كيلو تريد؟"]','["Kosakata transaksi","Angka dan jumlah","Kejelasan permintaan"]','مرحبًا بك في السوق. ماذا تريد أن تشتري اليوم؟',true),
('university','Di Universitas','في الجامعة','Membicarakan jadwal kuliah, jurusan, dan kehidupan kampus.',(select id from public.proficiency_levels where code='L2'),'["Menjelaskan jurusan","Membicarakan jadwal","Bertanya tentang kelas"]','["جامعة","محاضرة","قسم","جدول"]','["ماذا تدرس في الجامعة؟","متى تبدأ محاضرتك؟"]','["Kosakata kampus","Keterangan waktu","Respons relevan"]','أهلًا! نحن الآن في الجامعة. ماذا تدرس؟',true),
('library','Di Perpustakaan','في المكتبة','Meminta bantuan menemukan buku dan menjelaskan kebutuhan belajar.',(select id from public.proficiency_levels where code='L2'),'["Meminta bantuan","Menjelaskan topik buku"]','["كتاب","مكتبة","أبحث عن","رف"]','["عن أي موضوع تبحث؟","هل تحتاج إلى مساعدة؟"]','["Ungkapan permintaan","Kosakata buku"]','مرحبًا بك في المكتبة. عن أي موضوع تبحث اليوم؟',true),
('travel','Perjalanan','السفر','Membicarakan rencana perjalanan, transportasi, dan tujuan.',(select id from public.proficiency_levels where code='L3'),'["Menjelaskan rencana","Menanyakan transportasi","Menyebut tujuan"]','["سفر","تذكرة","محطة","رحلة"]','["إلى أين تريد أن تسافر؟","كيف ستصل إلى هناك؟"]','["Urutan cerita","Kosakata perjalanan"]','أهلًا بك! إلى أين تحب أن تسافر، ولماذا؟',true),
('daily-life','Kehidupan Sehari-hari','الحياة اليومية','Menceritakan rutinitas dan kebiasaan sehari-hari.',(select id from public.proficiency_levels where code='L2'),'["Menceritakan rutinitas","Menggunakan penanda waktu"]','["عادةً","صباحًا","بعد ذلك","مساءً"]','["ماذا تفعل في الصباح؟","كيف تقضي يومك؟"]','["Urutan kegiatan","Kata kerja","Keterangan waktu"]','مرحبًا! صف لي يومك المعتاد من الصباح إلى المساء.',true),
('doctor','Mengunjungi Dokter','زيارة الطبيب','Berlatih menjelaskan keluhan sederhana dan memahami pertanyaan umum.',(select id from public.proficiency_levels where code='L3'),'["Mendeskripsikan keluhan","Menjawab pertanyaan"]','["ألم","طبيب","أشعر","منذ"]','["ما الذي يؤلمك؟","منذ متى تشعر بذلك؟"]','["Kejelasan keluhan","Kosakata tubuh"]','أهلًا بك. ما الذي يؤلمك؟',true),
('academic-discussion','Diskusi Akademik','المناقشة الأكاديمية','Menyampaikan gagasan dan alasan dalam konteks akademik.',(select id from public.proficiency_levels where code='L4'),'["Menyatakan tesis","Memberi alasan"]','["أعتقد أن","لأن","من ناحية أخرى","نتيجة لذلك"]','["ما رأيك في هذا الموضوع؟","ما الأسباب التي تدعم رأيك؟"]','["Kejelasan argumen","Register akademik"]','مرحبًا. ما رأيك في أهمية تعلّم اللغات؟',true),
('express-opinion','Menyampaikan Pendapat','عرض الرأي','Menyatakan, menjelaskan, dan mempertahankan pendapat secara sopan.',(select id from public.proficiency_levels where code='L3'),'["Menyatakan pendapat","Memberi contoh"]','["في رأيي","أوافق","أختلف","على سبيل المثال"]','["ما رأيك في التعلّم عبر الإنترنت؟","لماذا تعتقد ذلك؟"]','["Pernyataan pendapat","Alasan dan contoh"]','أهلًا! ما رأيك في التعلّم عبر الإنترنت؟',true)
on conflict(slug) do update set title_id=excluded.title_id,title_ar=excluded.title_ar,description=excluded.description,minimum_level_id=excluded.minimum_level_id,learning_objectives=excluded.learning_objectives,vocabulary_targets=excluded.vocabulary_targets,suggested_prompts=excluded.suggested_prompts,evaluation_criteria=excluded.evaluation_criteria,opening_message=excluded.opening_message,is_published=true;

insert into public.vocabulary_items(arabic_text,indonesian_meaning,example_sentence,difficulty_level_id) values
('مَرْحَبًا','Halo / selamat datang','مَرْحَبًا، كَيْفَ حَالُكَ؟',(select id from public.proficiency_levels where code='L1')),
('اِسْم','Nama','مَا اسْمُكَ؟',(select id from public.proficiency_levels where code='L1')),
('جَامِعَة','Universitas','أَدْرُسُ فِي الْجَامِعَةِ.',(select id from public.proficiency_levels where code='L1')),
('أُرِيدُ','Saya ingin','أُرِيدُ كَوْبًا مِنَ الْمَاءِ.',(select id from public.proficiency_levels where code='L2')),
('لِأَنَّ','Karena','أُحِبُّ اللُّغَةَ الْعَرَبِيَّةَ لِأَنَّهَا جَمِيلَةٌ.',(select id from public.proficiency_levels where code='L3')),
('فِي رَأْيِي','Menurut pendapat saya','فِي رَأْيِي، الْقِرَاءَةُ مُهِمَّةٌ.',(select id from public.proficiency_levels where code='L3'))
on conflict(arabic_text) do nothing;
