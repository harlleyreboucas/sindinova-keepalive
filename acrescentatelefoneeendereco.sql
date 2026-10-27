-- =====================================================================
--  SINDINOVA - Acrescenta TELEFONE e ENDEREÇO ao cadastro de filiados
--  Cole no Supabase > SQL Editor e clique em "Run" (só precisa rodar 1 vez).
--  Os filiados já cadastrados continuam iguais; esses campos ficam vazios
--  até o administrador preencher.
-- =====================================================================

alter table public.filiados
  add column if not exists telefone text,
  add column if not exists endereco text;

-- telefone guardado só com números: DDD + 8 ou 9 dígitos (ex.: 69999998888)
alter table public.filiados
  drop constraint if exists filiados_telefone_formato;
alter table public.filiados
  add constraint filiados_telefone_formato
  check (telefone is null or telefone ~ '^[0-9]{10,11}$');
