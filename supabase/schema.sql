-- Turnix: tabelle + sicurezza (ogni utente vede e modifica solo i propri dati)
-- Da incollare in Supabase → SQL Editor → New query → Run

-- Parametri del cedolino (uno per utente)
create table public.settings (
  user_id    uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  avatar     text,
  updated_at timestamptz not null default now()
);

-- Turni (uno per riga; "deleted" serve alla sincronizzazione tra dispositivi)
create table public.shifts (
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id         text not null,
  data       jsonb not null,
  deleted    boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);
create index shifts_user_updated on public.shifts (user_id, updated_at);

-- Ora di modifica sempre decisa dal server
create or replace function public.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
create trigger settings_touch before insert or update on public.settings
  for each row execute function public.touch_updated_at();
create trigger shifts_touch before insert or update on public.shifts
  for each row execute function public.touch_updated_at();

-- Sicurezza a livello di riga: solo il proprietario
alter table public.settings enable row level security;
alter table public.shifts   enable row level security;

create policy "settings: solo il proprietario" on public.settings
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "shifts: solo il proprietario" on public.shifts
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Permessi per gli utenti che hanno fatto l'accesso (le regole sopra limitano comunque ai propri dati)
grant select, insert, update, delete on public.settings, public.shifts to authenticated;
