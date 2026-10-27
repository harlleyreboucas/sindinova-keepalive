-- =====================================================================
-- SISTEMA DE FILIADOS DO SINDICATO - SETUP DO SUPABASE
-- Cole TUDO isto em: Supabase > SQL Editor > New query > Run
-- =====================================================================

-- 1) Tabela de filiados -------------------------------------------------
create table if not exists public.filiados (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid unique references auth.users(id) on delete set null,
  nome_completo    text   not null,
  cpf              char(11) not null unique check (cpf ~ '^[0-9]{11}$'),
  data_nascimento  date   not null,
  filiado_desde    date   not null,
  email            text   not null unique,
  criado_em        timestamptz not null default now()
);

-- 2) Tabela de administradores -----------------------------------------
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

-- 3) Função que diz se quem está logado é administrador -----------------
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

-- 4) Segurança em nível de linha (RLS) ----------------------------------
alter table public.filiados enable row level security;
alter table public.admins   enable row level security;

drop policy if exists "admin faz tudo em filiados" on public.filiados;
create policy "admin faz tudo em filiados"
  on public.filiados for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "filiado le somente o proprio registro" on public.filiados;
create policy "filiado le somente o proprio registro"
  on public.filiados for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "usuario le a propria linha em admins" on public.admins;
create policy "usuario le a propria linha em admins"
  on public.admins for select
  to authenticated
  using (user_id = auth.uid());

-- 5) Vínculo automático entre a conta de login e o cadastro do filiado --
-- (a) Quando o filiado cria a conta (primeiro acesso), liga pelo e-mail
create or replace function public.vincular_filiado_ao_criar_conta()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.filiados
     set user_id = new.id
   where lower(email) = lower(new.email)
     and user_id is null;
  return new;
end;
$$;

drop trigger if exists trg_vincular_ao_criar_conta on auth.users;
create trigger trg_vincular_ao_criar_conta
  after insert on auth.users
  for each row execute function public.vincular_filiado_ao_criar_conta();

-- (b) Se a conta já existir quando o admin cadastrar/alterar o filiado
create or replace function public.vincular_conta_ao_salvar_filiado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.email := lower(trim(new.email));
  if new.user_id is null then
    select id into new.user_id
      from auth.users
     where lower(email) = new.email
     limit 1;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_vincular_ao_salvar on public.filiados;
create trigger trg_vincular_ao_salvar
  before insert or update of email on public.filiados
  for each row execute function public.vincular_conta_ao_salvar_filiado();


insert into public.admins (user_id)
select id from auth.users where email = 'contato@sindinova.org.br';
