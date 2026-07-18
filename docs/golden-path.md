# Golden Path — stack-ul standard pentru produse noi în ecosistem

Scop: aceleași alegeri repetate peste tot, ca oamenii și agenții de cod (Claude Code,
Codex) să schimbe repo-ul fără să schimbe dialectul. **Proiectele existente NU se
migrează retroactiv** (Prisma rămâne în Bizigniter, Fastify pur rămâne în Datero etc.);
orice produs NOU pleacă de aici.

## Limbaj & runtime
- TypeScript end-to-end, Node ≥22, `pnpm` (10.x) + workspace-uri unde e monorepo.
- Identifiers/cod/DB în **engleză**; UI/copy/docs în **română**. Bani în unități minore
  (bigint) + currency. ID-uri: UUIDv7 generate în aplicație.

## Backend
- **NestJS 11 pe adapterul Fastify** pentru API-uri de produs (referință: Facturare).
  Pentru servicii subțiri, API-first fără UI de produs: Fastify pur + TypeBox (referință: Datero).
- **PostgreSQL 17 + Drizzle ORM** (+ drizzle-kit pentru migrări).
- **Multi-tenancy**: `tenant_id NOT NULL` pe fiecare tabelă tenant-scoped + **RLS
  ENABLE+FORCE** cu politică pe `current_setting('app.tenant_id')`, setat DOAR prin
  `withTenant()` (tranzacție + `set_config(..., true)` = SET LOCAL). Rol DB aplicativ
  non-superuser NOBYPASSRLS separat de rolul de migrare. Referințe: CRM
  (`server/db/tenant.ts`) și Facturare (`apps/api/src/db/tenant-db.ts`) — identice ca idee.
- Redis (ioredis) pentru sesiuni/cache/cozi; BullMQ pentru joburi (referință: Facturare worker).
- Validare la margine cu Zod (sau TypeBox în varianta Fastify pur).

## Identitate & acces (vezi ADR-001)
- Login prin **Companero ID** (Zitadel): Authorization Code + PKCE.
- Web: pattern **BFF** — token-urile OIDC nu ajung în browser; sesiune server-side în
  Redis, cookie httpOnly cu ID opac (referință: Facturare `apps/web/src/app/auth/*`).
- Mobil: `expo-auth-session` PKCE.
- API/MCP inbound: validare JWKS sau introspection RFC 7662.
- Rolurile/permisiunile se definesc **în aplicație**, enforcement pe permisiune, nu pe rol
  (referință: Facturare `packages/shared/src/constants/access.ts`).
- S2S: API keys pe header dedicat, hash-uite la stocare (referință: Datero `api-keys.ts`).

## Frontend
- Next.js 15+ App Router + React 19, Tailwind 4; shadcn/ui unde e UI bogat (referință: CRM).
- Mobil: Expo + expo-router (referințe: Bizigniter, Companero Mobile).

## Calitate
- Biome (lint+format), Vitest; Playwright pentru e2e unde există UI.
- CI pe PR: Biome → typecheck → Vitest → migrări+RLS integration tests
  (referință: `.github/workflows/ci.yml` din Facturare).

## Operare
- Dockerfile multi-stage `node:22-alpine`, user non-root, `HEALTHCHECK` pe `/health`
  (referință: `datero/api/Dockerfile`).
- Deploy: **Dokploy pe Hetzner**; secretele trăiesc în **Dokploy → Environment**
  (Dokploy rescrie `.env` la deploy — lecție învățată pe companero-ai). PG dedicat per
  produs (nu se partajează instanțe între produse).
- Backup: pgdump→R2 nightly per produs (vezi PLAN.md B4). Observabilitate: `/health` în
  uptime-kuma + Sentry DSN per proiect (B3).
- Porturi locale: rezervă-le în `docs/port-registry.md` din acest repo ÎNAINTE de a
  alege (istoric de coliziuni ad-hoc).
- Cronuri pe prod: orice cron nou = **disabled** până la decizia explicită a lui Marian.

## Date Companero
- Sateliții **cheamă** Companero (`/api/v1`), Companero nu cheamă sateliții.
- Datele de firmă **nu se replică** — se cache-uiesc cu TTL (Redis cache-aside — Datero),
  se salvează ca snapshot pe entitatea proprie la momentul folosirii (Facturare `partner`,
  Bizigniter `Share`) sau tabelă de enrichment cu TTL (CRM). Alege pattern-ul după caz.
- Integrarea Companero = enhancement **best-effort**, nu dependență hard: aplicația
  funcționează și cu Companero căzut (referință: Facturare `company-lookup.service.ts`).
- Țintă (PLAN.md C4): client generat `@companero/api-client` din OpenAPI, în locul
  clienților scriși de mână.

## Context pentru agenți
- Fiecare repo are: `CLAUDE.md` (working agreement), `AGENTS.md` → symlink la CLAUDE.md
  (pentru Codex), `docs/CONTEXT.md` (cartea de vizită pentru sesiuni cross-proiect,
  1–2 pagini: ce expune, ce consumă, auth, env, cum pornește local).
- Când ai nevoie de contextul altui proiect: citește `<vecin>/docs/CONTEXT.md`,
  NU tot repo-ul vecinului.
