-- =====================================================================
--  SINDINOVA - Permite ao ADMINISTRADOR definir a senha de um filiado
--  Cole no Supabase > SQL Editor e clique em "Run" (só precisa rodar 1 vez).
--
--  O que faz:
--   • Se o filiado JÁ tem acesso: troca a senha dele.
--   • Se o filiado AINDA NÃO tem acesso: cria o acesso já confirmado,
--     com a senha informada (não envia e-mail nenhum).
--  Segurança:
--   • Só funciona para quem está na tabela public.admins.
--   • Só funciona para e-mails que estão cadastrados em public.filiados.
--   • Não permite alterar a senha de outro administrador.
-- =====================================================================

create or replace function public.admin_definir_senha(p_email text, p_senha text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(trim(p_email));
  v_uid   uuid;
begin
  -- 1) quem está chamando precisa ser administrador
  if not exists (select 1 from public.admins a where a.user_id = auth.uid()) then
    raise exception 'Apenas administradores podem definir senhas.';
  end if;

  -- 2) validações
  if p_senha is null or length(p_senha) < 8 then
    raise exception 'A senha precisa ter pelo menos 8 caracteres.';
  end if;

  if not exists (select 1 from public.filiados f where lower(f.email) = v_email) then
    raise exception 'Este e-mail não está cadastrado como filiado.';
  end if;

  -- 3) já existe acesso? então só troca a senha
  select u.id into v_uid from auth.users u where lower(u.email) = v_email limit 1;

  if v_uid is not null then
    if exists (select 1 from public.admins a where a.user_id = v_uid) then
      raise exception 'Não é permitido alterar a senha de um administrador por aqui.';
    end if;

    update auth.users
       set encrypted_password = extensions.crypt(p_senha, extensions.gen_salt('bf')),
           email_confirmed_at = coalesce(email_confirmed_at, now()),
           updated_at = now()
     where id = v_uid;

    return 'alterada';
  end if;

  -- 4) não existe acesso: cria já confirmado
  v_uid := gen_random_uuid();

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000', v_uid, 'authenticated', 'authenticated',
    v_email, extensions.crypt(p_senha, extensions.gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    '', '', '', ''
  );

  insert into auth.identities (
    id, user_id, provider_id, provider, identity_data,
    last_sign_in_at, created_at, updated_at
  ) values (
    gen_random_uuid(), v_uid, v_uid::text, 'email',
    jsonb_build_object('sub', v_uid::text, 'email', v_email, 'email_verified', true),
    now(), now(), now()
  );

  return 'criada';
end;
$$;

-- Só usuários logados podem chamar (e a função ainda confere se é admin)
revoke all on function public.admin_definir_senha(text, text) from public, anon;
grant execute on function public.admin_definir_senha(text, text) to authenticated;
