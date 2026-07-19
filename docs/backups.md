# Backup-uri — bazele PostgreSQL de PROD (B4)

**Configurat 2026-07-19, prin API-ul Dokploy** (mecanismul nativ: pg_dump programat +
upload R2 + retenție; vizibil per serviciu în tab-ul Backups).

## Organizare în R2

- Bucket: **`backups`** (DEDICAT, creat de Marian 2026-07-19; token R2 scoped DOAR pe
  el — `~/.secrets/r2-dokploy` pe Mac). Bucketul `companero` NU mai e folosit pentru
  backup-urile Dokploy (varianta inițială de acolo a fost curățată — DOAR obiectele de
  test create în aceeași zi; `backup/`-ul core, neatins, rămâne mecanismul propriu al
  companero.ro în bucketul `companero`).
- Destinație Dokploy: `r2-dokploy-backups` → bucket `backups`.
- **⚠️ Layout real**: Dokploy prefixează cu appName-ul serviciului:
  `<appName>/<nume>/<timestamp>.sql.gz`:
  - `companeroid-zitadeldb-2ygqbc/zitadel-prod/…`
  - `postgres-input-neural-program-mlostx/facturare-prod/…`
  - `postgres-calculate-mobile-hard-drive-maijea/crm-prod/…`
  - `datero-postgres-vfqhal/datero-prod/…`
  - `bizigniter-db-r4ks2v/bizigniter-prod/…`
- **⚠️ Formatul e pg_dump CUSTOM (header `PGDMP`), deși extensia e `.sql.gz`** —
  restore cu `pg_restore`, NU cu psql!

## Programare (zilnic) + retenție 14

| Bază | Cron (UTC) | DB name real |
|---|---|---|
| zitadel-db (Companero ID prod) | 03:10 | `zitadel` |
| facturare-db | 03:20 | `facturare` |
| crm-db | 03:30 | `crm` |
| datero-postgres | 03:40 | `datero` |
| bizigniter-db | 03:50 | **`bizigniter-db`** (⚠️ numele bazei = numele serviciului, capcană descoperită la primul run) |

Excluse deliberat: staging-urile (regenerabile), PG-ul companero-ai (feature store
reconstruit săptămânal din build), core-ul (mecanism propriu existent).

## Verificat la configurare (2026-07-19)

- Backup manual declanșat pe toate 5 → obiecte confirmate în bucketul `backups`
  (10–112 KB gz; re-rulat după mutarea pe bucketul dedicat).
- **Test de restore REAL** pe dump-ul crm: `pg_restore --no-owner` într-un postgres:17
  descartabil (cu rolurile `crm`/`crm_app` create întâi) → 0 erori, 18 tabele,
  datele prezente, 13 politici RLS restaurate.

## Procedura de restore (pe scurt)

```bash
# 1. descarcă dump-ul din R2 (boto3/aws cli cu ~/.secrets/r2-dokploy)
# 2. gunzip -c dump.sql.gz > dump  (format custom!)
# 3. pe țintă: creează rolurile aplicative + baza, apoi:
pg_restore --no-owner -d <db> dump
# 4. re-verifică politici RLS + parolele rolurilor (ALTER ROLE ... PASSWORD)
```

## De făcut cândva

- Alerta pe backup eșuat: Dokploy nu notifică nativ pe backup failure — opțional un
  monitor kuma pe „vârsta ultimului obiect" per prefix (script mic) sau verificare
  lunară manuală.
- Test de restore periodic (trimestrial) — repetă procedura de mai sus pe altă bază.
