-- =====================================================================
-- Cheque Manager Pro - Schéma PostgreSQL (Supabase) pour la PHASE 2
-- Synchronisation multi-appareils. Miroir exact du schéma SQLite local :
-- mêmes identifiants UUID, mêmes colonnes, horodatages pour la résolution
-- des conflits (dernière modification gagnante + journal conservé).
-- Exécuter dans Supabase > SQL Editor.
-- =====================================================================

create table if not exists banques (
  id uuid primary key,
  owner_id uuid not null default auth.uid() references auth.users(id),
  nom text not null,
  agence text not null default '',
  ville text not null default '',
  titulaire text not null default '',
  reference_compte text not null default '',
  infos text not null default '',
  archive boolean not null default false,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  device_id text
);

create table if not exists chequiers (
  id uuid primary key,
  owner_id uuid not null default auth.uid() references auth.users(id),
  banque_id uuid not null references banques(id),
  numero text not null,
  premier integer not null,
  dernier integer not null check (dernier >= premier),
  largeur integer not null default 7,
  date_ouverture date not null,
  statut text not null default 'actif' check (statut in ('actif','termine','archive')),
  created_at timestamptz not null,
  updated_at timestamptz not null,
  device_id text,
  unique (banque_id, numero)
);

create table if not exists cheques (
  id uuid primary key,
  owner_id uuid not null default auth.uid() references auth.users(id),
  banque_id uuid not null references banques(id),
  chequier_id uuid not null references chequiers(id),
  numero integer not null,
  montant bigint not null check (montant > 0),          -- centimes de MAD
  date_edition date not null,
  date_presentation date not null,
  beneficiaire text not null,
  ville text not null default '',
  objet text not null default '',
  observations text not null default '',
  statut text not null default 'en_attente'
    check (statut in ('en_attente','presente','paye','impaye','recupere','detruit')),
  rappels_actifs boolean not null default true,
  motif_rejet text not null default '',
  frais_rejet bigint not null default 0,
  date_statut timestamptz,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  device_id text,
  unique (banque_id, numero)
);
create index if not exists idx_cheques_owner_maj on cheques(owner_id, updated_at);

create table if not exists historique_statuts (
  id uuid primary key,
  owner_id uuid not null default auth.uid() references auth.users(id),
  cheque_id uuid not null references cheques(id),
  ancien text,
  nouveau text not null,
  date timestamptz not null,
  commentaire text not null default '',
  justificatif_id uuid
);

create table if not exists pieces_jointes (
  id uuid primary key,
  owner_id uuid not null default auth.uid() references auth.users(id),
  cheque_id uuid not null references cheques(id),
  type text not null check (type in ('photo','pdf')),
  nom text not null,
  fichier text not null,             -- chemin dans le bucket Storage "pieces"
  created_at timestamptz not null,
  deleted_at timestamptz,
  remplacee_par uuid
);

create table if not exists journal (
  id uuid primary key,
  owner_id uuid not null default auth.uid() references auth.users(id),
  date timestamptz not null,
  entite text not null,
  entite_id text not null,
  action text not null,
  resume text not null default '',
  details jsonb not null default '{}'::jsonb,
  device_id text
);

-- Le journal et l'historique sont en ajout seul : aucune modification ni
-- suppression possible depuis l'application (traçabilité intégrale).
-- Les chèques ne sont jamais supprimés physiquement côté serveur.

alter table banques enable row level security;
alter table chequiers enable row level security;
alter table cheques enable row level security;
alter table historique_statuts enable row level security;
alter table pieces_jointes enable row level security;
alter table journal enable row level security;

do $$
declare t text;
begin
  foreach t in array array['banques','chequiers','cheques','pieces_jointes'] loop
    execute format('drop policy if exists "%1$s_proprietaire" on %1$s', t);
    execute format('create policy "%1$s_proprietaire" on %1$s for all
                    using (owner_id = auth.uid()) with check (owner_id = auth.uid())', t);
  end loop;
  foreach t in array array['historique_statuts','journal'] loop
    execute format('drop policy if exists "%1$s_lecture" on %1$s', t);
    execute format('drop policy if exists "%1$s_ajout" on %1$s', t);
    execute format('create policy "%1$s_lecture" on %1$s for select using (owner_id = auth.uid())', t);
    execute format('create policy "%1$s_ajout" on %1$s for insert with check (owner_id = auth.uid())', t);
  end loop;
end $$;

-- Interdit la suppression physique d'un chèque autre que "en attente".
create or replace function empecher_suppression_cheque() returns trigger as $$
begin
  if old.statut <> 'en_attente' then
    raise exception 'Un chèque % ne peut pas être supprimé', old.statut;
  end if;
  return old;
end $$ language plpgsql;

drop trigger if exists trg_suppression_cheque on cheques;
create trigger trg_suppression_cheque before delete on cheques
  for each row execute function empecher_suppression_cheque();

-- Stockage des photos et PDF : créer un bucket privé "pieces"
-- (Storage > New bucket > pieces, Public = non), puis :
-- create policy "pieces_proprietaire" on storage.objects for all
--   using (bucket_id = 'pieces' and owner = auth.uid())
--   with check (bucket_id = 'pieces' and owner = auth.uid());
