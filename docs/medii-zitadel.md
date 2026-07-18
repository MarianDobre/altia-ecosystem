# Mediile Zitadel („Companero ID") — local / staging / prod

Răspunde la întrebarea operațională: *cum lucrez cu Zitadel local și pe
test.companero.ro? Am nevoie de `id.test.companero.ro`?* — **Da, pentru staging; local nu
ai nevoie de domeniu, doar de instanța partajată pe `localhost:8082`.**

## Principiul care face totul să meargă: două URL-uri per mediu

Toate aplicațiile (pattern deja implementat în Facturare) configurează IdP-ul prin două
variabile distincte:

- `ZITADEL_BROWSER_URL` — ce vede **browserul** (redirect-uri de login). Trebuie să fie
  atins de omul care se loghează.
- `ZITADEL_INTERNAL_URL` — ce văd **containerele** (token endpoint, introspection, JWKS).
  Merge pe rețeaua internă Docker, nu iese pe internet.

Separarea asta rezolvă și Cloudflare Access pe staging (vezi jos): backchannel-ul S2S nu
trece niciodată prin Cloudflare.

## Local — o singură instanță partajată, portul canonic 8082

**Regula: un singur Zitadel local pentru tot ecosistemul, pe `http://localhost:8082`.**

Azi, instanța canonică este cea din compose-ul Facturare
(`companero.facturare/infra/docker-compose.local.yml`, serviciile `zitadel` + `zitadel-db`),
deja bootstrapată idempotent de `companero.facturare/scripts/zitadel-bootstrap.sh`
(admin local: `admin@facturare.local`; PAT de provisioning în `infra/.zitadel/`).
**Nu duplicăm instanța** — alt Zitadel local ar însemna al doilea set de conturi/clienți
OIDC care diverge.

Pornire de oriunde, prin justfile-ul din acest repo:

```bash
just idp-up     # pornește DOAR zitadel + zitadel-db din compose-ul Facturare
just idp-down
just idp-status
```

Fiecare proiect care se integrează local primește propriul client OIDC în această
instanță (bootstrap script per proiect, după modelul Facturare) și configurează:
`ZITADEL_BROWSER_URL=http://localhost:8082`, iar dacă rulează în Docker pe aceeași
rețea: `ZITADEL_INTERNAL_URL=http://zitadel:8080` (altfel tot `localhost:8082`).

*Viitor (când ≥2 proiecte îl folosesc activ local):* extragem serviciile într-un
`compose/idp/docker-compose.yml` în acest repo și îl scoatem din compose-ul Facturare.
Portul 8082 rămâne canonic ca să nu se schimbe nicio configurare de aplicație.

## Staging — `id.test.companero.ro` (instanță separată)

**Da, ai nevoie de el.** OIDC-ul are redirect-uri de browser cu domenii fixe per client —
nu poți loga pe `test.companero.ro` (sau pe staging-urile CRM/Facturare) prin IdP-ul de
prod fără să amesteci userii și redirect URI-urile de test cu cele reale.

- Proiect Dokploy separat pe Hetzner: `zitadel` + `postgres:17` dedicat (NU partajat cu
  prod și NU cu PG-ul altui produs).
- DNS Cloudflare `id.test.companero.ro`. Poate sta **după Cloudflare Access**, la fel ca
  `test.companero.ro` — e chiar de dorit (staging privat): omul trece o singură dată de
  Access, apoi redirect-urile OIDC funcționează normal în browser. Backchannel-ul
  aplicațiilor (token/introspection/JWKS) folosește `ZITADEL_INTERNAL_URL` pe rețeaua
  Docker internă (`http://<serviciu-zitadel-staging>:8080`), deci nu atinge Cloudflare.
- Config Zitadel: `ZITADEL_EXTERNALDOMAIN=id.test.companero.ro`, `ZITADEL_EXTERNALSECURE=true`,
  TLS terminat de Cloudflare/Traefik (tlsMode external).
- Useri de test separați de prod; bootstrap cu același script, parametrizat pe domeniu.

## Prod — `id.companero.ro`

- Proiect Dokploy separat, PG17 dedicat, `ZITADEL_EXTERNALDOMAIN=id.companero.ro`, public
  (fără Cloudflare Access), Cloudflare proxied + Full (strict).
- **Backup nightly pgdump→R2 din prima zi** — DB-ul Zitadel devine cea mai critică bază
  din ecosistem (fără el nu se mai loghează nimeni, nicăieri).
- SMTP: Zoho (tranzacțional, ca restul companero.ro) pentru verificări de email/reset.
- Branding „Companero ID" (logo, culori) — un singur brand de login pentru toate produsele
  (decizia 2 din ADR-001).
- Masterkey-ul Zitadel (cheia de criptare) se generează unic pe mediu și se păstrează în
  Dokploy Environment + un backup offline; pierderea lui = instanță nerecuperabilă.

## Maparea env-urilor per aplicație (exemplu)

| Mediu | BROWSER_URL | INTERNAL_URL |
|---|---|---|
| local | `http://localhost:8082` | `http://zitadel:8080` (sau localhost:8082 dacă app-ul nu e în Docker) |
| staging | `https://id.test.companero.ro` | `http://<zitadel-staging>:8080` (rețea Dokploy) |
| prod | `https://id.companero.ro` | `http://<zitadel-prod>:8080` (rețea Dokploy) |

Fiecare aplicație are câte un client OIDC **per mediu** (client_id diferit local/staging/prod),
cu redirect URI-urile mediului respectiv. Nu se refolosește clientul între medii.
