# Companero ID — deploy prod (id.companero.ro)

Runbook-ul pasului **A1** din PLAN.md. Zitadel e software de raft (imaginea oficială) —
**nu există repo/Dockerfile propriu**; sursa de adevăr pentru configurare e
`docker-compose.prod.yml` de aici, lipit în Dokploy ca serviciu Compose. Orice
modificare de config se face ÎNTÂI aici (commit), apoi în Dokploy.

Layout-ul e ca la Datero (proiect Dokploy cu DB gestionat + serviciu aplicativ),
cu diferența că serviciul aplicativ e imagine de raft, nu build din repo.

## Pași (Dokploy UI pe Hetzner, https://<dokploy>:3000)

### 1. Cloudflare (zona companero.ro)
- DNS → A record: `id` → `88.99.96.16`, **Proxied**.
- SSL/TLS: zona e deja Full (strict) — nimic de schimbat dacă e setat la nivel de zonă.

### 2. Dokploy — proiect + Postgres
- Create Project: `companero-id`.
- În proiect: **Create Service → Database → PostgreSQL**, nume `zitadel-db`,
  imagine `postgres:17-alpine`, database `zitadel`, user `zitadel`, parolă generată
  (`openssl rand -hex 24`). Deploy.
- Din pagina serviciului DB, copiază **Internal Host** (ceva de forma
  `companero-id-zitadeldb-xxxxxx`) → devine `PG_HOST` la pasul 3.
- **Backups (bifează B4 pentru Zitadel)**: tab-ul Backups al serviciului DB →
  destinație S3 = bucket-ul R2 existent (endpoint-ul contului Cloudflare R2,
  access key/secret dedicate), schedule zilnic (ex. 03:10), retenție ≥ 14.

### 3. Dokploy — serviciul Zitadel (Compose)
- **Create Service → Compose**, nume `zitadel`, provider **Raw** → lipește conținutul
  `docker-compose.prod.yml`.
- Tab **Environment** — setează (valorile NU se comit nicăieri):
  - `ZITADEL_VERSION` — ultima stabilă de pe https://github.com/zitadel/zitadel/releases (pin explicit, fără `latest`)
  - `ZITADEL_MASTERKEY` — `openssl rand -hex 16` (exact 32 caractere; salvează și un backup offline — pierdut = instanță nerecuperabilă)
  - `PG_HOST` — internal host-ul de la pasul 2
  - `PG_PASSWORD` — parola DB de la pasul 2
  - `ADMIN_USERNAME` / `ADMIN_EMAIL` — contul tău de administrator al instanței
  - `ADMIN_PASSWORD` — temporară, o schimbi la primul login (Zitadel o cere)
- Deploy. Urmărește log-urile: primul boot rulează `init` + migrațiile (~1 min).

### 4. Domeniul
- La serviciul Compose → **Domains → Add**: host `id.companero.ro`,
  service `zitadel`, container port `8080`, HTTPS on (Let's Encrypt — funcționează
  prin proxy-ul Cloudflare, același pattern ca Datero).
- Verificare: `curl -s https://id.companero.ro/debug/healthz` → `ok`;
  consola pe `https://id.companero.ro/ui/console`.

### 5. Post-instalare (în consolă, ca admin)
- [ ] Schimbă parola admin + activează **MFA** pe contul admin.
- [ ] Instance → **Branding**: „Companero ID", logo + culori Companero (decizia 2, ADR-001).
- [ ] Instance → **SMTP**: Zoho (tranzacțional companero.ro) — from gen
      `id@companero.ro`; trimite un mail de test.
- [ ] Default Settings → Login Policy: dezactivează register public dacă nu-l vrem
      încă (userii vin prin JIT/invitații la început).
- [ ] Notează: PAT-ul contului `provisioner` e în volumul `zitadel_machinekey`
      (`docker exec <container> cat /machinekey/pat.txt`) — îl folosim la A2/A3/A7
      pentru crearea programatică a clienților OIDC per aplicație.

### 6. Închidere A1
- Bifează A1 în `PLAN.md` + intrare în jurnal + commit în repo-ul `ecosystem`.
- Adaugă monitorizarea `https://id.companero.ro/debug/healthz` când există uptime-kuma (B3).

## Capcanele primului deploy (2026-07-18) — TOATE rezolvate în compose-ul curent

Șapte probleme înlănțuite până la primul boot reușit; le enumăr ca staging-ul (A1b) să
iasă din prima. Compose-ul din acest director le are deja pe toate încorporate:

1. **`ZITADEL_VERSION` gol** → imagine `zitadel:` invalidă. Pin explicit (ex. `v4.16.1`).
2. **Serviciul DB necreat efectiv** — a fost definit în UI dar nepornit (Deploy pe
   serviciul Database e pas separat). Simptom: `hostname resolving error` la boot.
3. **`--masterkeyFromEnv` lipsă** — Zitadel NU citește `ZITADEL_MASTERKEY` din env fără
   acest flag („no master key provided").
4. **Dokploy strică timestamp-urile YAML** la re-serializare → PAT expiration prin
   `${PAT_EXPIRATION}` din Environment, nu literal în YAML.
5. **Volumul machinekey root-owned** → `open /machinekey/pat.txt: permission denied`,
   care lasă instanța PE JUMĂTATE inițializată („Instance.Domain.AlreadyExists" la
   fiecare restart). Fix: chmod/chown pe volum ÎNAINTE de primul boot; dacă s-a
   întâmplat deja: `DROP DATABASE zitadel; CREATE DATABASE zitadel OWNER zitadel;` și boot curat.
6. **Politica de parolă** pentru `ADMIN_PASSWORD`: minim 8, majusculă+minusculă+cifră+simbol
   (și atenție la copy-paste în `ADMIN_EMAIL` — un `)` rătăcit a costat un ciclu).
7. **Healthcheck-ul `zitadel ready` probează HTTPS** dacă TLS nu e oprit prin env
   (`ZITADEL_TLS_ENABLED=false`) — flag-urile comenzii de start NU ajung la probe.
   Container never-healthy = Traefik nu rutează (404 cu cert default).

8. **Login V2 activ implicit în v4** → primul login în consolă redirecționează spre
   `/ui/v2/login/...` care dă `{"code":5,"message":"Not Found"}` — noul login e o
   APLICAȚIE SEPARATĂ (container `zitadel-login`) pe care n-o rulăm. Fix (post-boot,
   cu PAT-ul provisionerului din volumul machinekey):
   ```bash
   curl -H "Authorization: Bearer $PAT" -H "Content-Type: application/json" \
     -X PUT https://id.companero.ro/v2/features/instance -d '{"loginV2":{"required":false}}'
   ```
   (identic cu ce face `companero.facturare/scripts/zitadel-bootstrap.sh` local).
   Aplicat pe prod 2026-07-18 (HTTP 200). Dacă vrem vreodată UI-ul de login nou,
   deployăm containerul `zitadel-login` și re-activăm feature-ul.

Plus: **Dokploy nu injectează label-uri Traefik pentru Compose Raw** — tab-ul Domains e
inert aici; rutarea se face DOAR prin `traefik.*` labels scrise de noi în compose
(provider-ul Docker e activ, `exposedByDefault: false`). Deploy-urile „Done/verzi" în
Dokploy înseamnă doar `docker compose up` reușit — starea reală se vede în
`docker logs`, nu în UI.

## Note operaționale
- **Upgrade Zitadel** = schimbi `ZITADEL_VERSION` (citind release notes — rulează migrări
  de DB automat) → redeploy. Fă backup manual R2 înainte de upgrade-uri majore.
- Staging (`id.test.companero.ro`, pas A1b): același runbook, proiect Dokploy separat
  `companero-id-test`, DB separat, alt masterkey; poate sta după Cloudflare Access —
  vezi `docs/medii-zitadel.md`.
- Clienții OIDC per aplicație NU se creează manual din consolă — prin bootstrap script
  (pattern `companero.facturare/scripts/zitadel-bootstrap.sh`), câte unul per mediu.
