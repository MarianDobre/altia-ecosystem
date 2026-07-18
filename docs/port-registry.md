# Registrul de porturi locale (host)

Regulă: înainte să alegi un port host nou într-un `docker-compose` sau script de dev,
**verifică și rezervă aici** (commit în același PR/sesiune). Istoric: porturile de până
acum au fost alese ad-hoc și au început să se aglomereze.

## Rezervate azi

| Port | Proiect | Serviciu |
|---|---|---|
| 80/443 | companero core | Traefik (`companero.docker.local`) |
| 1026 | facturare | Mailpit SMTP |
| 3000 | facturare | web (Next dev) ⚠️ |
| 3000 | bizigniter | web (Next dev) ⚠️ conflict cu facturare — nu rula ambele simultan |
| 3001 | facturare | api (NestJS) |
| 3005 | facturare | Gotenberg |
| 4000 | bizigniter | api (NestJS) |
| 4321 | datero | web (Astro dev) |
| 5434 | bizigniter | PostgreSQL 16 |
| 5435 | companero.crm | PostgreSQL 17 |
| 5436 | facturare | PostgreSQL 17 |
| 6381 | facturare | Redis |
| 8026 | facturare | Mailpit UI |
| 8082 | **ecosistem (IdP)** | **Zitadel local partajat** — port canonic, nu se schimbă (azi găzduit de compose-ul Facturare; vezi `docs/medii-zitadel.md`) |
| 8100 | companero-ai | FastAPI |
| 9002/9005 | facturare | MinIO API / Console |
| 9200 | companero core | Elasticsearch |
| 27018 | companero core | MongoDB (arhivă) |

## De completat (nedocumentate încă)

- companero core local: porturile host pentru PG17, Redis, Mailhog/Mailpit (dacă există) —
  de extras din `docker-companies/docker-compose.local.yml` la prima ocazie.
- datero local: portul API în dev (3000 în container; de verificat mapping-ul host — posibil
  conflict cu facturare/bizigniter web).

## Convenție pentru viitor

- PG-uri noi: continuă seria 543x (următorul liber: **5437**).
- Redis noi: seria 638x (următorul liber: **6382**).
- API-uri noi: seria 40xx (următorul liber: **4001**).
- Web dev noi: evită 3000 (dublu ocupat); folosește 30xx (următorul liber: **3002**).
