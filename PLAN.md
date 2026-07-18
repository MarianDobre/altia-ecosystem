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

- [ ] **A1. Zitadel prod pe Dokploy** (`id.companero.ro`) — **ÎN LUCRU (2026-07-18)**
  - Runbook complet + compose versionat: **`compose/idp/README.md`** +
    `compose/idp/docker-compose.prod.yml` (Zitadel = imagine de raft, fără repo/Dockerfile
    propriu; PG = serviciu Database Dokploy cu backup R2 din UI → acoperă și B4 pt Zitadel).
  - Rămas de executat în Dokploy UI + Cloudflare: pașii 1–6 din runbook.
  - Branding „Companero ID", SMTP Zoho, MFA admin: pasul 5 din runbook.
  - Detalii medii + pattern-ul BROWSER_URL/INTERNAL_URL: `docs/medii-zitadel.md`.
- [ ] **A1b. Zitadel staging** (`id.test.companero.ro`) — instanță separată de prod,
  proiect Dokploy propriu, poate sta după Cloudflare Access ca test.companero.ro
  (backchannel-ul S2S merge pe rețeaua internă Docker, nu e afectat). Vezi `docs/medii-zitadel.md`.
- [ ] **A2. Facturare pe Zitadel prod/staging** — repointare env (`ZITADEL_*`).
  Depinde de: A1 (sau A1b), B2-facturare (Dockerfile). Implementarea BFF PKCE există deja.
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
- [ ] **B2. Dockerfile-uri lipsă** — CRM și Facturare (api/web/worker), după template-ul
  Datero (multi-stage node:22-alpine, non-root, healthcheck `/health`).
- [ ] **B3. Observabilitate comună** — uptime-kuma pe Dokploy (toate `/health`-urile,
  alerte în Slack-ul existent Companero) + Sentry (DSN per proiect; întâi Bizigniter + Facturare).
- [ ] **B4. Backups standard** — script pgdump→R2 parametrizat, ca serviciu în fiecare
  stack Dokploy: Zitadel (odată cu A1!), Datero, Bizigniter, apoi CRM/Facturare la deploy.
  Model: backup-ul R2 existent al Companero core (vezi memoria/deploy-ul core).
- [ ] **B5. CI uniform** — pipeline-ul Facturare (Biome→typecheck→Vitest→migrări+RLS)
  replicat în CRM, Bizigniter, Datero unde lipsește.

## Flux C — Contract & context agenți

- [x] **C1. `docs/CONTEXT.md` per proiect** (2026-07-18) — „cartea de vizită" de ~2 pagini
  a fiecărui proiect, scrisă pentru a fi încărcată în sesiunea ALTUI proiect. Creat în:
  core, companero-ai, mobile, CRM, Facturare, Datero, Bizigniter. + Secțiune „Ecosistem"
  în CLAUDE.md-ul fiecărui repo cu tabelul căilor + regula „citește CONTEXT.md-ul vecinului".
- [x] **C2. `AGENTS.md` peste tot** (2026-07-18) — symlink către CLAUDE.md în toate
  repo-urile (Codex citește AGENTS.md). companero-ai a primit și un CLAUDE.md nou (nu avea).
- [ ] **C3. `permissions.additionalDirectories`** în `.claude/settings.local.json` per repo,
  către siblings-ii atinși frecvent. Se face incremental, când se lucrează în fiecare repo.
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

- **2026-07-18 (Fable)** — Analiză completă a celor 7 proiecte (rapoarte de explorare pe
  stack/auth/deploy/integrare). Deciziile 1–5 confirmate de Marian. Constatări-cheie:
  4 modele de auth coexistă; Bizigniter are anti-pattern de login delegat (parola Companero
  + token-uri Companero stocate în DB-ul lui) — de rezolvat la A3 înainte de App Store;
  4 clienți Companero scriși de mână (→ C4); ORM divergent (Prisma în Bizigniter vs Drizzle
  restul — nu se migrează, dar golden path = Drizzle). Executat: **B1** (acest repo),
  **C1** (CONTEXT.md × 7 + secțiuni Ecosistem în CLAUDE.md-uri), **C2** (AGENTS.md × 8,
  CLAUDE.md nou în companero-ai). Fișierele din repo-urile satelit sunt lăsate necomise —
  Marian le comite per repo.
