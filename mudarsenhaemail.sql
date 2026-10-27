update auth.users
set encrypted_password = extensions.crypt('sindinova1', extensions.gen_salt('bf'))
where email = 'contato@sindinova.org.br';
