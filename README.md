# Altia / Companero — repo meta de ecosistem

Repo-ul de coordonare al ecosistemului Companero: planul-master, deciziile de arhitectură
(ADR-uri), convențiile comune (golden path), registrul de porturi și uneltele de lucru
local cross-proiect. **Nu conține cod de produs.**

- **[PLAN.md](PLAN.md)** — planul-master cu stadiul fiecărui pas + jurnalul de progres.
  Orice sesiune de lucru (om sau agent) pornește de aici.
- **[docs/adr/](docs/adr/)** — decizii de arhitectură de ecosistem (ADR-001: Zitadel IdP central).
- **[docs/golden-path.md](docs/golden-path.md)** — stack-ul standard pentru produse noi.
- **[docs/medii-zitadel.md](docs/medii-zitadel.md)** — cum rulează „Companero ID" local /
  staging (`id.test.companero.ro`) / prod (`id.companero.ro`).
- **[docs/port-registry.md](docs/port-registry.md)** — porturile locale rezervate.
- **justfile** — `just idp-up|idp-down|idp-status` (Zitadel local partajat) + utilitare.

## Harta proiectelor

| Proiect | Cale locală | Rol | Găzduire |
|---|---|---|---|
| Companero (core) | `~/docker/altia/docker-companies/src/companies` | Platforma principală (Symfony 7.4, PG17, ES) | Netcup (prod) + Hetzner (staging) |
| Companero AI | `~/docker/altia/companero-ai` | Motor recomandări (FastAPI, pgvector) | Dokploy/Hetzner |
| Companero Mobile | `~/docker/altia/companero-mobile` | App mobilă Companero (Expo/RN) | EAS (viitor) |
| Companero CRM | `~/docker/altia/companero.crm` | CRM multi-tenant (Next 15, tRPC, Drizzle, RLS) | Dokploy (viitor) |
| Companero Facturare | `~/docker/altia/companero.facturare` | Facturare SaaS (NestJS, Next, Drizzle, RLS, Zitadel) | Dokploy (viitor) |
| Datero | `~/docker/altia/datero` | API pentru dezvoltatori (Fastify, better-auth, Stripe) | Dokploy (live) |
| Bizigniter | `~/docker/altia/bizigniter` | Prospectare/vânzări, mobil (Expo + NestJS + Prisma) | Dokploy + EAS |
| Ansible | `~/docker/altia/ansible_automation` | Provisioning/deploy Companero core (Netcup) | — |

Fiecare proiect are `docs/CONTEXT.md` — cartea de vizită de citit când lucrezi din alt
proiect și ai nevoie de contextul lui (nu citi tot repo-ul vecin).
