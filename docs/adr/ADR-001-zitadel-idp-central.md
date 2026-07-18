# ADR-001 — Zitadel ca IdP central al ecosistemului („Companero ID")

- **Status:** Acceptat (Marian, 2026-07-18)
- **Înlocuiește:** planul „Companero core ca IdP OIDC" din `companero.crm/docs/ARCHITECTURE.md`
  §10.2 + Decision Log 2026-06-16 (de corectat acolo la pasul A4 din PLAN.md).

## Context

La momentul deciziei, ecosistemul avea **patru modele de identitate** care coexistau:

| Proiect | Auth la 2026-07-18 |
|---|---|
| Companero core | Lexik JWT (`/api/token` email+parolă) + API keys `cmpk_*` + OAuth propriu doar pt MCP (incomplet ca OIDC: fără `/userinfo`, fără ID token) |
| Mobile | Lexik JWT + refresh; layer izolat (un singur punct de injectare Bearer) |
| Bizigniter | ⚠️ login delegat: colectează parola Companero a userului, o trimite la `/api/token`, stochează token-urile Companero în DB-ul propriu, emite JWT propriu |
| Datero | Identitate proprie better-auth (magic-link only) + API keys `dat_live_*` + provider OAuth 2.1 propriu pt MCP; billing Stripe complet |
| CRM | better-auth email+parolă; multi-tenant RLS; plan scris „Sign in with Companero" |
| Facturare | **Zitadel implementat real local**: BFF PKCE (token-urile nu ajung în browser), sesiuni Redis server-side, introspection RFC 7662 pt MCP, JIT provisioning pe `oidc_sub`, bootstrap idempotent |
| companero-ai | API key statică `X-Api-Key`, S2S only |

Costul fragmentării devine vizibil la lansările publice: un client Companero ar avea
conturi separate pe fiecare produs, iar Bizigniter poartă un anti-pattern de securitate
(password sharing între aplicații) problematic și la review-ul Apple.

## Decizie

**Zitadel self-hosted devine IdP-ul central** al ecosistemului, sub brandul „Companero ID":

- Prod: `id.companero.ro` (Dokploy/Hetzner, PG17 dedicat, backup R2 nightly).
- Staging: `id.test.companero.ro` (instanță separată). Local: o singură instanță partajată
  (vezi `docs/medii-zitadel.md`).
- **Toate aplicațiile — inclusiv Companero core — sunt relying parties egale.**
  Nicio aplicație de produs nu deține identitatea alteia.
- Flow standard: Authorization Code + PKCE; pe web pattern BFF (token-urile rămân
  server-side), pe mobil `expo-auth-session`; pt MCP/API: validare JWKS sau
  introspection RFC 7662 (pattern-ul din Facturare).

## Motivație (de ce nu Companero core ca IdP)

1. Companero core e legacy declarat; un provider OIDC complet (ID tokens, `/userinfo`,
   DCR, revocare, consent, back-channel logout) ar fi o investiție mare exact în stack-ul
   pe care nu-l migrăm. OAuth-ul lui actual pt MCP e departe de OIDC complet.
2. IdP-ul trebuie să fie cea mai stabilă piesă; core-ul e piesa cu cele mai multe
   schimbări/migrații. Un incident pe core nu trebuie să doboare login-ul sateliților.
3. Jumătate din muncă există deja în Facturare (BFF PKCE, introspection, bootstrap).
4. Zitadel e battle-tested, operabil de un singur om pe Dokploy (spre deosebire de un
   Keycloak mai greu operațional) și bine cunoscut de LLM-uri/agenți.

## Granițe — ce NU centralizăm

- **Autorizarea**: rolurile/permisiunile rămân în fiecare aplicație (Zitadel spune
  *cine ești*, aplicația decide *ce ai voie*). Pattern consacrat: Facturare
  (`packages/shared/src/constants/access.ts`, enforcement pe permisiune).
- **Tenancy**: fiecare produs își ține `tenant`/`organization` local, legat de userul
  global prin `oidc_sub` (JIT provisioning). O „organizație de ecosistem" partajată =
  proiect ulterior opțional.
- **Billing**: rămâne per-produs (Stripe la Datero, Netopia la Companero/Facturare).
  Unificarea billing-ului = respinsă explicit (capcană de complexitate).
- **S2S**: rămâne pe API keys (companero-ai, satelit→Companero). Client credentials
  prin Zitadel = rafinare opțională târzie.

## Consecințe / migrare

Pașii A1–A7 din `PLAN.md`. Puncte fixe:

- **Un singur Companero ID** peste tot (decizia 2): branding unificat la login,
  inclusiv pe Bizigniter și Datero.
- **Datero: federare blândă** (decizia 4): better-auth rămâne manager local; Zitadel
  devine provider OIDC upstream; linking pe email; conturi + Stripe neatinse.
- **Bizigniter** își elimină complet delegarea de parolă înainte de App Store (A3).
- **Companero core** acceptă tranzitoriu ambele token-uri (Lexik + Zitadel via JWKS);
  login-ul legacy are sunset natural, fără forțare (A5).
- Lansarea oficială Companero **nu depinde** de nimic din acest ADR (decizia 3).
