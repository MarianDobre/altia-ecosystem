# Plan de ecosistem — identitate, devops, context agenți

> **Acesta este documentul-master al lucrării.** Orice sesiune (Claude Fable, Claude Opus,
> Codex sau om) care reia lucrul pornește de AICI: citește acest fișier cap-coadă, apoi
> ADR-urile din `docs/adr/`, apoi `docs/CONTEXT.md` al proiectelor pe care le atinge pasul
> curent. La finalul fiecărei sesiuni de lucru: bifează pașii finalizați, adaugă o intrare
> în **Jurnalul de progres** (jos) și commit în acest repo.

**Ultima actualizare:** 2026-07-18 (sesiune Fable — analiză + decizii + B1/C1/C2)

---

## Context și decizii (confirmate de Marian, 2026-07-18)

Ecosistemul = Companero core (Symfony legacy, prod Netcup) + sateliți TS/Python
(CRM, Facturare, Datero, Bizigniter, Mobile, companero-ai) pe Dokploy/Hetzner.
Analiza completă a stării fiecărui proiect: vezi `docs/adr/ADR-001-zitadel-idp-central.md`
(secțiunea Context) și `docs/CONTEXT.md` din fiecare repo.

Deciziile de fond — **nu se re-deschid fără Marian**:

1. **Zitadel = IdP central** la `id.companero.ro`. Companero core devine relying party.
   Planul vechi „Companero ca IdP" din docs-urile CRM e abandonat (de corectat în CRM la A4).
2. **Un singur „Companero ID"** — același cont peste tot, inclusiv Bizigniter și Datero.
3. **Lansarea Companero (mobilpay) nu se blochează pe SSO.** Întâi infrastructura,
   core-ul se mufează ulterior.
4. **Datero: federare blândă** — rămâne pe better-auth, se adaugă „Sign in with Companero ID"
   ca provider OIDC upstream, linking pe email. Conturile + Stripe neatinse.
5. **Billing per-produs** — doar identitatea se centralizează, nu billingul.

Principii derivate (necontestate): authZ (roluri/permisiuni) rămâne în fiecare aplicație;
tenancy rămâne locală per produs, legată prin `oidc_sub`; S2S rămâne pe API keys.

---

## Flux A — Identitate (Zitadel)

- [x] **A1. Zitadel prod pe Dokploy** (`id.companero.ro`) — **LIVE 2026-07-18** ✅
  - Verificat: healthz ok, cert Let's Encrypt real la origin, OIDC discovery
    (issuer `https://id.companero.ro`), consolă 200, container healthy, PAT provisioner
    scris în volumul machinekey. Zitadel v4.16.1, proiect Dokploy `companero-id`
    (compose `zitadel` + DB `zitadel-db`/postgres:18).
  - Runbook + compose versionat: `compose/idp/` — include TOATE capcanele primului
    deploy (secțiunea „Capcanele primului deploy" din README — citește-o înainte de A1b!).
  - Login + parolă nouă + MFA făcute de Marian ✔. **SMTP Brevo funcțional** (2026-07-18,
    verificat cu email real; capcanele 9–11 în runbook — Hetzner blochează 465, semantica
    `tls`, bug-ul endpoint-ului de password). Register public OFF pe AMBELE instanțe (2026-07-18, via API) ✔.
    Rămas: branding „Companero ID" (consolă) + ~~rotația PAT-ului provisioner~~ FĂCUTĂ 2026-07-18 (vechiul PAT revocat).
  - **Rămas ops:** verificat/configurat backup-ul R2 al serviciului `zitadel-db` din
    tab-ul Backups (pasul 2 din runbook); Cloudflare zonă → Full (strict) acum că
    originul are cert valid.
  - Detalii medii + pattern-ul BROWSER_URL/INTERNAL_URL: `docs/medii-zitadel.md`.
- [x] **A1b. Zitadel staging** (`id.test.companero.ro`) — **DEPLOYAT 2026-07-18** ✅
  - Proiect Dokploy `Companero.test.id` (creat integral prin API): `zitadel-db`
    (postgres:18) + compose `zitadel` (serviciu `zitadel-test`). Boot din PRIMA
    (capcanele 1–8 pre-rezolvate; volum machinekey pre-creat cu permisiuni). loginV2
    dezactivat. Compose: `compose/idp/docker-compose.test.yml`. Masterkey: Dokploy
    Environment + copie `~/.secrets/zitadel-test-masterkey`.
  - DNS adăugat de Marian (A gri → 88.99.96.16), cert Let's Encrypt emis și VERIFICAT
    2026-07-18 (healthz ok pe TLS strict, OIDC discovery, consolă 200). Notă operațională:
    după adăugarea DNS-ului a fost nevoie de un restart al containerului zitadel-test ca
    Traefik să re-declanșeze ACME (primul attempt căzuse pe NXDOMAIN pre-DNS).
  - Admin staging: login + parolă nouă făcute de Marian ✔. **SMTP Brevo funcțional**
    (2026-07-18, verificat cu email real, sender „Companero ID (test)").
  - Backup R2 pe `zitadel-db` (staging): de configurat din tab Backups (mai puțin
    critic decât prod, dar ieftin).
- [x] **A2. Facturare pe Companero ID (prod)** — **FĂCUT + VERIFICAT 2026-07-18** ✅
  - Provisioning pe id.companero.ro cu PAT (pattern zitadel-bootstrap.sh): proiect Zitadel
    `facturare` (382322592658227202), app WEB PKCE `facturare-web` (client_id
    382322592926728194, redirect https://facturare.companero.ro/auth/callback) + app API
    basic `facturare-api` (introspecție MCP). Env-uri injectate în Dokploy, web+api
    redeployate.
  - Verificat: `/auth/login` → 307 către id.companero.ro/oauth/v2/authorize cu PKCE S256.
    Login end-to-end de testat de Marian (JIT provisioning la primul login).
  - Staging (facturare.test.companero.ro): la deploy-ul de staging — client separat pe
    id.test.companero.ro, același script.
  - **Groundwork Dokploy FĂCUT (2026-07-18, prin API):** proiecte prod `Companero.facturare`
    (postgres:17 `facturare-db` + `facturare-redis`) și `Companero.crm` (postgres:17 `crm-db`),
    toate deployate. Parolele DB: în Dokploy UI (serviciile Database). DNS Cloudflare
    adăugat de Marian: `facturare`/`crm` (proxied) + `facturare.test`/`crm.test` (gri).
  - **Blocat pe Marian:** repo-uri GitHub pentru `companero.facturare`, `companero-mobile`,
    `ecosystem` (recomandat: MarianDobre/companero-facturare, /companero-mobile,
    /altia-ecosystem, private) — apoi push + legarea aplicațiilor în Dokploy din GitHub.
  - **Facturare DEPLOYAT pe prod Dokploy (2026-07-18)** — 4 servicii live în proiectul
    `Companero.facturare`: `facturare-gotenberg` (imagine gotenberg:8), `facturare-api`
    (:3001, intern), `facturare-web` (**https://facturare.companero.ro → 200**, LE),
    `facturare-worker` — toate build-uite din GitHub `MarianDobre/facturare` cu
    `dockerBuildStage` pe Dockerfile-ul unic (autodeploy ON). Roluri RLS create pe
    `facturare-db` (facturare_app NOBYPASSRLS / facturare_maintenance BYPASSRLS, parole
    generate; owner=userul Dokploy `facturare`); migrații 0000–0007 aplicate one-off cu
    `docker exec … node dist/db/migrate.js`. Env complet (DSN-uri, Redis cu parolă, SMTP
    Brevo, GOTENBERG_URL, ANAF_MOCK=1, PAYMENTS_MOCK=1, ZITADEL_* → id.companero.ro,
    ZITADEL_CLIENT_ID gol până la A2).
    - Bugfix găsit la deploy: worker-ul arunca user/parola din REDIS_URL → NOAUTH pe prod
      (fix comis `3fda0a8` în repo-ul facturare).
    - GitHub: Marian a creat câte o aplicație Dokploy per repo (`Dokploy-companero-*`);
      aplicațiile din Dokploy au fost repoint-ate pe providerul `Dokploy-companero-facturare`.
    - Capcane API Dokploy: `application.saveEnvironment` cere și `buildArgs`/`buildSecrets`/
      `createEnvFile`; la Applications, tab-ul Domains FUNCȚIONEAZĂ (spre deosebire de
      Compose Raw).
    - Rămase pt A2/M2-real: client OIDC (bootstrap cu PAT), `S3_*` (bucket R2 — de la
      Marian), `ANAF_*` real, Netopia real. Backup R2 pe facturare-db → B4.
- [ ] **A3. Bizigniter pe OIDC nativ** — ⚠️ obligatoriu ÎNAINTE de submisia App Store.
  - `expo-auth-session` PKCE în `apps/mobile`; echivalent în `apps/web`.
  - API-ul validează JWT Zitadel (JWKS) în loc de JWT propriu emis din parola Companero.
  - Se elimină stocarea `companeroToken`/`companeroRefreshToken` din tabela User.
  - Tranzitoriu (până la A5): apelurile spre Companero se fac cu API key de serviciu, server-side.
  - Linking useri beta pe email la primul login cu Companero ID.
- [ ] **A4. CRM pe Zitadel upstream** — provider OIDC generic în better-auth,
  „Sign in with Companero ID" lângă email+parolă, linking pe email.
  - Tot aici: **corectarea `docs/ARCHITECTURE.md` §10.2 + Decision Log** din CRM
    (înlocuit „Companero ca IdP" cu decizia Zitadel — referință: ADR-001 de aici).
- [ ] **A5. Companero core ca relying party** (legacy touch, chirurgical; „când va fi cazul")
  - Symfony OIDC access-token handler: `/api/v1` acceptă și JWT Zitadel (JWKS), în paralel cu Lexik.
  - Buton „Intră cu Companero ID" pe web; linking pe email verificat + stamp `oidc_sub` pe `app_user`.
  - Lexik/parola locală rămân funcționale — sunset natural.
- [ ] **A6. Mobile Companero pe OIDC** — `expo-auth-session` în locul `/api/token`.
  Layer-ul e izolat (un singur punct de injectare Bearer în `src/api/client.ts`). Depinde de A5.
- [ ] **A7. Datero — federare blândă** — provider OIDC upstream în better-auth,
  linking pe email; magic-link + Stripe neatinse. Depinde doar de A1.

Ordine obligatorie: A1 → (A2, A3, A4, A7); A5 → A6. A3 are deadline natural (App Store).

## Flux B — DevOps / standardizare

- [x] **B1. Repo meta `ecosystem`** — acest repo (creat 2026-07-18): PLAN.md, ADR-001,
  `docs/golden-path.md`, `docs/port-registry.md`, `docs/medii-zitadel.md`, `justfile`
  (inclusiv `idp-up` pentru Zitadel local — deleghează la compose-ul Facturare, vezi
  `docs/medii-zitadel.md` § Local).
- [x] **B2. Dockerfile-uri producție CRM + Facturare** — **FĂCUT 2026-07-18** (2 agenți
  Opus, ambele verificate cu docker build + boot local; fișierele NECOMISE în repo-urile
  de produs — Marian le comite la primul deploy):
  - **CRM**: `Dockerfile` multi-stage standalone (241 MB) + `.dockerignore` + rută nouă
    `app/api/health/route.ts` + `output:'standalone'` în next.config.ts. Env dummy DOAR
    în stage-ul de build (Zod runtime intact). Migrații = pas de deploy (`pnpm db:migrate`
    cu DSN owner), documentat în header.
  - **Facturare**: UN `Dockerfile` la rădăcină cu 3 targets `api`/`web`/`worker`
    (212/238/175 MB) + `.dockerignore` (exclude .env* și infra/.zitadel!) +
    `outputFileTracingRoot` în apps/web/next.config.mjs. `pnpm deploy --legacy` per app;
    migrațiile Drizzle rulabile din imaginea api: `node dist/db/migrate.js` cu
    `MIGRATION_DATABASE_URL` (owner) — în Dokploy ca Pre-deploy command. Worker fără
    HEALTHCHECK HTTP (intenționat, consumator BullMQ).
  - Repo-uri GitHub create de Marian + push-uite: `MarianDobre/facturare`,
    `/companero-mobile`, `/altia-ecosystem` (toate legate din local).
- [~] **B3. Observabilitate comună** — **uptime-kuma DEPLOYAT 2026-07-18** (proiect
  Dokploy `Monitoring`, imagine louislam/uptime-kuma:1, volum persistent,
  **https://status.companero.ro**). ⚠️ RĂMAS: (1) Marian își creează contul admin la
  prima accesare (pagina de setup e publică până atunci — fă-o repede!); (2) adăugarea
  monitoarelor (/health-urile: facturare web+api via domeniu, datero, bizigniter, id +
  id.test /debug/healthz, companero.ro) + notificare Slack; (3) Sentry (DSN per proiect).
- [ ] **B4. Backups standard — TOATE proiectele Dokploy** (cerut explicit de Marian
  2026-07-18, „nu am timp acum" — de programat o sesiune dedicată). Preferabil prin
  tab-ul Backups al serviciilor Database Dokploy (S3→R2, nativ) unde există serviciu
  Database; script pgdump→R2 doar unde DB-ul e în compose. De acoperit: `zitadel-db`
  (prod **prioritar** + staging), `datero-postgres`, `bizigniter-db`, PG-ul companero-ai
  (feature store, în compose), apoi CRM/Facturare la deploy. Verificat și restore-ul, nu
  doar dump-ul. Model: backup-ul R2 al Companero core.
- [ ] **B5. CI uniform** — pipeline-ul Facturare (Biome→typecheck→Vitest→migrări+RLS)
  replicat în CRM, Bizigniter, Datero unde lipsește.

## Flux C — Contract & context agenți

- [x] **C1. `docs/CONTEXT.md` per proiect** (2026-07-18) — „cartea de vizită" de ~2 pagini
  a fiecărui proiect, scrisă pentru a fi încărcată în sesiunea ALTUI proiect. Creat în:
  core, companero-ai, mobile, CRM, Facturare, Datero, Bizigniter. + Secțiune „Ecosistem"
  în CLAUDE.md-ul fiecărui repo cu tabelul căilor + regula „citește CONTEXT.md-ul vecinului".
- [x] **C2. `AGENTS.md` peste tot** (2026-07-18) — symlink către CLAUDE.md în toate
  repo-urile (Codex citește AGENTS.md). companero-ai a primit și un CLAUDE.md nou (nu avea).
- [x] **C3. `permissions.additionalDirectories`** — FĂCUT 2026-07-18: `ecosystem` adăugat
  în settings.local.json la toate cele 6 repo-uri (+ companero-ai la bizigniter, core la
  mobile).
- [ ] **C4. SDK Companero generat** (post-lansare) — publicare `/api/v1/openapi.json` stabil
  în core + pachet `@companero/api-client` (GitHub Packages); înlocuiește treptat cei 4
  clienți scriși de mână (CRM `lib/companero/client.ts`, Facturare `company-lookup.service.ts`,
  Datero `api/src/services/companero.ts`, Bizigniter `apps/api/src/companero/companero.service.ts`).

---

## Cum reiei lucrul (instrucțiuni pentru orice agent/model)

1. Citește acest PLAN.md integral, apoi `docs/adr/ADR-001-zitadel-idp-central.md`.
2. Identifică următorul pas nebifat din fluxul cerut de Marian (sau întreabă-l ce flux atacă).
3. Înainte de a atinge un proiect, citește `<cale-proiect>/docs/CONTEXT.md` (nu tot repo-ul),
   apoi CLAUDE.md-ul lui dacă lucrezi efectiv în el. Căile: vezi tabelul din README.md.
4. Nu re-deschide deciziile 1–5 de mai sus fără Marian. Regula cronuri/costuri: pe prod,
   orice cron nou = disabled până la decizia explicită a lui Marian.
5. La final: bifează, scrie în jurnal, commit aici. Dacă ai modificat fișiere în alte
   repo-uri, spune-i lui Marian ce e necomis acolo (nu comite în repo-urile lui fără să ceară).
6. Notă: sesiunile Claude Code din workspace-ul Companero core au și o memorie persistentă
   proprie (`ecosystem-projects-map`, `ecosystem-auth-strategy`) — oglindește deciziile de
   aici, dar **PLAN.md e sursa de adevăr**; la divergență, actualizează memoria, nu planul.

## Jurnalul de progres

- **2026-07-18 (Fable, sesiunea 2b) — A1b DEPLOYAT integral prin API Dokploy** (proiect
  `Companero.test.id`, postgres + compose + deploy + loginV2 off), autonom, boot din
  prima în ~20s. Corecție documentată în `docs/medii-zitadel.md`: `id.test.companero.ro`
  = subdomeniu pe 2 niveluri → Universal SSL nu-l acoperă → DNS **gri** (fără Access pe
  IdP-ul de staging). Rămas: Marian adaugă A-recordul gri → certul LE se emite singur.
  Pe prod (A1): loginV2 dezactivat (capcana 8), Marian a făcut login + parolă nouă + MFA.

- **2026-07-18 (Fable, sesiunea 2) — A1 LIVE.** `id.companero.ro` funcțional cap-coadă
  (Zitadel v4.16.1 pe Dokploy, DB dedicat, LE cert, OIDC discovery, PAT provisioner).
  Debug în 7 pași — capcanele documentate în `compose/idp/README.md`. Unelte noi:
  SSH server = `altia@88.99.96.16` (docker direct); API Dokploy funcțional cu token în
  `~/.secrets/dokploy-token` (panel: `panel.altia.work`) — update compose/env + deploy
  prin API merge complet. Rămase pe A1: pasul 5 manual (login/MFA/branding/SMTP) +
  verificare backup R2 pe `zitadel-db` + CF Full (strict).

- **2026-07-18 (Fable)** — Analiză completă a celor 7 proiecte (rapoarte de explorare pe
  stack/auth/deploy/integrare). Deciziile 1–5 confirmate de Marian. Constatări-cheie:
  4 modele de auth coexistă; Bizigniter are anti-pattern de login delegat (parola Companero
  + token-uri Companero stocate în DB-ul lui) — de rezolvat la A3 înainte de App Store;
  4 clienți Companero scriși de mână (→ C4); ORM divergent (Prisma în Bizigniter vs Drizzle
  restul — nu se migrează, dar golden path = Drizzle). Executat: **B1** (acest repo),
  **C1** (CONTEXT.md × 7 + secțiuni Ecosistem în CLAUDE.md-uri), **C2** (AGENTS.md × 8,
  CLAUDE.md nou în companero-ai). Fișierele din repo-urile satelit sunt lăsate necomise —
  Marian le comite per repo.
