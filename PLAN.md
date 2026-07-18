# Plan de ecosistem — identitate, devops, context agenți

> **Acesta este documentul-master al lucrării.** Orice sesiune (Claude Fable, Claude Opus,
> Codex sau om) care reia lucrul pornește de AICI: citește acest fișier cap-coadă, apoi
> ADR-urile din `docs/adr/`, apoi `docs/CONTEXT.md` al proiectelor pe care le atinge pasul
> curent. La finalul fiecărei sesiuni de lucru: bifează pașii finalizați, adaugă o intrare
> în **Jurnalul de progres** (jos) și commit în acest repo.

**Ultima actualizare:** 2026-07-18 (sesiune Fable, runda 3 — A2/A4/A7 live, CRM deployat, SSO confirmat pe toate trei)

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
   core-ul se mufează ulterior. (2026-07-18 seara: A5 în lucru COD-ONLY pe agent — nu se
   deployează pe Netcup fără decizia lui Marian.)
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
  - **STAGING LIVE (2026-07-18, agent Opus)**: proiect Dokploy `Companero.facturare.test`
    complet — PG+roluri RLS, Redis, Gotenberg, api/web/worker din același repo/branch
    (autodeploy ON ⇒ staging-ul urmărește main-ul împreună cu prod-ul), migrații
    aplicate, client OIDC pe id.test (web `382337404071117237` + introspecție),
    domeniu `facturare.test.companero.ro` (LE pe DNS gri). Verificat: /backend/health
    ok+db up, /auth/login → 307 spre id.test, worker fără erori. Secretele: în
    scratchpad state local + Dokploy Environment.
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
    - Bugfix #2 (post-A2, găsit la primul login real): rewrites-ul Next `/backend/*` se
      evaluează LA BUILD cu output standalone → proxy înghețat pe localhost:3001
      (ECONNREFUSED pe orice apel API din browser; login-ul părea „nu face nimic").
      Fix `f2489df`: route handler runtime `app/backend/[...path]/route.ts` care citește
      `API_PROXY_URL` per-request. Verificat: /backend/health → {"status":"ok","db":"up"}.
    - GitHub: Marian a creat câte o aplicație Dokploy per repo (`Dokploy-companero-*`);
      aplicațiile din Dokploy au fost repoint-ate pe providerul `Dokploy-companero-facturare`.
    - Capcane API Dokploy: `application.saveEnvironment` cere și `buildArgs`/`buildSecrets`/
      `createEnvFile`; la Applications, tab-ul Domains FUNCȚIONEAZĂ (spre deosebire de
      Compose Raw).
    - Rămase pt A2/M2-real: client OIDC (bootstrap cu PAT), `S3_*` (bucket R2 — de la
      Marian), `ANAF_*` real, Netopia real. Backup R2 pe facturare-db → B4.
- [x] **A3. Bizigniter pe OIDC nativ** — **LIVE PE PROD 2026-07-18** ✅ (agent Opus +
  review; commit `b12ef33`, autodeploy, migrarea aplicată la boot). Verificat:
  `/auth/login` 404 (dispărut), `/auth/me` 401 fără token (guard JWKS activ), butonul pe
  bizigniter.app/login. Anti-pattern-ul password-sharing ELIMINAT complet.
  - Clienți OIDC (proiect Zitadel `bizigniter`): mobil `382327214865121282` (NATIVE,
    `bizigniter://auth`, JWT), web `382327215150333954` (USER_AGENT, `/auth/callback`,
    JWT). eas.json are valorile pe preview/production → următorul build EAS iese cu
    Companero ID.
  - Cheie de serviciu Companero emisă pe Netcup (`app:api-key:issue`, tier business,
    scope read, user marian) → `COMPANERO_API_KEY` în env bizigniter-api. `JWT_SECRET`/
    `JWT_EXPIRES_IN` scoase din env.
  - Bugfix-uri post-deploy (găsite la testul lui Marian, ambele fixate+push-uite):
    CSP-ul web bloca fetch-urile PKCE către issuer (`connect-src` fără id.companero.ro —
    fix 8f6fa4c; regulă pt ORICE client PKCE viitor din ecosistem) și navigarea
    client-side post-callback lăsa AuthProvider-ul pe starea veche → loader infinit pe
    /discover (fix ad940c5: window.location.replace).
  - Follow-up-uri închise (2026-07-18, runda 4): (1) ✅ verificare `audience` în guard
    (env `COMPANERO_ID_AUDIENCES`, setat pe prod, commit 0bffacb); (2) ✅ cheia cmpk
    orfană REVOCATĂ pe Netcup (`UPDATE api_key SET revoked_at` pe id-ul vechi; a rămas
    doar 8b0ad722); rămase: (3) build EAS mobil (Marian); (4) tier `internal` pe cheie
    doar dacă beta lovește limitele business.
- [x] **A4. CRM pe Companero ID** — **COD COMPLET 2026-07-18** ✅ (agent Opus, comis
  `f56c7d9` + push): genericOAuth PKCE opt-in pe `COMPANERO_ID_*` (nesetate ⇒ identic cu
  azi), linking pe email DOAR cu email local verificat (gardă anti-takeover verificată în
  sursa better-auth), buton pe login/signup cu flag server-side request-time, docs
  ARCHITECTURE §10.1–10.2 corectate (planul „Companero ca IdP" SUPERSEDED → ADR-001).
  Loop verde: typecheck/lint/test 40-40/build/e2e 6-6.
  - **CRM DEPLOYAT PE PROD + SSO CONFIRMAT DE MARIAN (2026-07-18)** ✅:
    **https://crm.companero.ro** live — aplicație Dokploy `crm` în proiectul
    `Companero.crm` (GitHub MarianDobre/crm, autodeploy ON, Dockerfile single-target),
    domeniu + LE. Client OIDC `crm-web-login` pe id.companero.ro (proiect Zitadel `crm`,
    auth POST, redirect /api/auth/oauth2/callback/companero-id). Env: DSN owner (migrații)
    + `crm_app` (runtime RLS) + BETTER_AUTH_* + COMPANERO_ID_*.
    Migrațiile rulate one-off din stage-ul `build` al imaginii
    (`docker build --target build` din codul deployat + `pnpm db:migrate` pe
    dokploy-network — pattern reutilizabil; runner-ul provizionează și rolul crm_app).
    Capcană notată: între deploy și migrații, SSO-ul dă „Autentificarea a eșuat"
    (better-auth fără tabele) — la orice mediu nou: migrațiile ÎNAINTE de primul login.
- [~] **A5. Companero core ca relying party** — **COD COMPLET 2026-07-18 (agent Opus +
  review Fable), NECOMIS în repo-ul core, NEDEPLOYAT** (deploy = decizie Marian):
  - Livrat: CompaneroIdController (PKCE web login, client confidențial), 
    CompaneroIdTokenAuthenticator pe firewall-ul api (JWKS RS256 prin ext-openssl, FĂRĂ
    dependințe noi; iss/exp/aud), provisioner fail-closed (linking DOAR pe email
    verificat), migrare `app_user.oidc_sub` (nerulată), buton RO pe login (vizibil doar
    cu env-urile setate), docs modules/auth + nod manual + manual:lint OK. Verificat:
    lint container/twig, schema:validate, phpunit 4/4 (JWK→PEM byte-identic cu
    openssl!), kernel smoke pe ambele rute. Review Fable pe extractor+security.yaml:
    inert fără env-uri, Lexik/cmpk neatinse.
  - **ÎN PROD din 2026-07-18, DEZACTIVAT** (env-urile goale; migrarea oidc_sub aplicată).
  - **Activare (sesiune de design cu Marian):** (1) client Zitadel WEB confidențial per mediu,
    redirect EXACT `{APP_URL}/auth/companero-id/callback`; (2) pe proiectul Zitadel:
    „Assert Access Token as JWT" (altfel calea API cere introspection — nu e în A5);
    (3) env-urile `COMPANERO_ID_*` în deploy; (4) migrarea; (5) deploy Ansible manual.
  - Lexik/parola locală rămân funcționale — sunset natural.
- [ ] **A6. Mobile Companero pe OIDC** — `expo-auth-session` în locul `/api/token`.
  Layer-ul e izolat (un singur punct de injectare Bearer în `src/api/client.ts`). Depinde de A5.
- [x] **A7. Datero — federare blândă** — **LIVE PE PROD 2026-07-18** ✅ (aprobat de
  Marian): cod agent Opus (genericOAuth opt-in pe `COMPANERO_ID_*`, `GET /v1/auth/config`,
  buton login.astro, linking pe email verificat, magic-link/Stripe neatinse, teste 45/45)
  comis `bbee3bb` + autodeploy; client OIDC `datero-web-login` pe id.companero.ro (proiect
  `datero`, auth POST, redirect api.datero.ro/api/auth/oauth2/callback/companero); env în
  Dokploy pe datero-api. VERIFICAT: /v1/auth/config → enabled:true, butonul pe /login.

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
- [~] **B3. Observabilitate comună** — **monitoarele CONFIGURATE 2026-07-18**: 12/12 UP
  pe status.companero.ro (uptime-kuma-api, script reutilizabil), notificare email Brevo
  default pe toate. Detalii: `docs/monitoring.md`. **Sentry LIVE 2026-07-18**: org `altia-wf`, 3 proiecte
  (bizigniter/facturare/crm) create prin API (token în `~/.secrets/sentry-token`),
  DSN-urile distribuite în 9 aplicații Dokploy (prod+staging, SENTRY_ENVIRONMENT
  diferențiat), SDK-uri integrate de 3 agenți Opus (errors-only, tracesSampleRate 0,
  sendDefaultPii false, env-gated, fără sourcemaps; bizigniter web cu tunnelRoute
  /monitoring pt CSP) — toate deployate și verificate (health-uri ok, sentry în
  bundle, 12/12 monitoare UP). Rămase opționale: Slack webhook pt kuma,
  @sentry/react-native în bizigniter mobile. Istoric: — **uptime-kuma DEPLOYAT 2026-07-18** (proiect
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

- **2026-07-18 (Fable, runda 5) — A5 ÎN PROD (dezactivat) + incident scurt.** La cererea
  lui Marian, A5 comis pe main (`fa432f0`) și deployat pe Netcup prin Ansible, cu
  feature-ul stins (env-urile goale). **Incident ~15 min**: placeholder-ele goale din
  .env au dat `base_uri=""` la scoped client → HttpClient arunca la construcția
  authenticatorului → 500 pe TOT /api/v1 (web-ul neafectat); prins de smoke-ul automat
  din deploy. Hotfix pe prod (.env.local cu URL-uri valide) → API restabilit instant;
  permanentizat în core `.env` (`1c5f9c9`) + template-ul ansible (comis acolo).
  Smoke final: 21/21 PASSED. Migrarea `oidc_sub` e aplicată pe prod. Lecții: (1)
  placeholder-ele de env pentru URL-uri trebuie să fie valide, nu goale; (2)
  verificarea locală pre-deploy trebuie să lovească și firewall-ul API, nu doar
  paginile web. Activarea A5 = sesiune de design cu Marian (pașii în secțiunea A5).

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
