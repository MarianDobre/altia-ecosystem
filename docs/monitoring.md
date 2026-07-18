# Monitorizare — uptime-kuma (status.companero.ro)

Instanța: proiect Dokploy `Monitoring`, `https://status.companero.ro` (cont admin: Marian;
credențiale local pe Mac în `~/.secrets/uptime-kuma`). **CONFIGURAT 2026-07-18 prin
`uptime-kuma-api`** (venv + script în scratchpad-ul sesiunii; pattern reutilizabil):
12 monitoare, toate UP la configurare, interval 60s, retry 2, notificare email
**Brevo → marian.dobre@gmail.com** setată default pe toate (Slack: de adăugat când
există un incoming webhook — bot-token-ul core nu e compatibil cu uptime-kuma).

## Monitoarele configurate (live)

| Nume | URL | Așteptat |
|---|---|---|
| Companero core (prod) | `https://companero.ro/` | 200 |
| Companero ID (IdP prod) | `https://id.companero.ro/debug/healthz` | 200, keyword `ok` |
| Companero ID (IdP staging) | `https://id.test.companero.ro/debug/healthz` | 200, keyword `ok` |
| Facturare web (prod) | `https://facturare.companero.ro/` | 200 |
| Facturare api (prin BFF) | `https://facturare.companero.ro/backend/health` | 200, keyword `"status":"ok"` |
| Facturare staging | `https://facturare.test.companero.ro/backend/health` | 200 (după ridicarea staging-ului) |
| CRM | `https://crm.companero.ro/api/health` | 200, keyword `ok` |
| Datero api | `https://api.datero.ro/health` | 200 |
| Datero web | `https://datero.ro/` | 200 |
| Bizigniter api | `https://api.bizigniter.app/api/v1/health` | 200, keyword `ok` |
| Bizigniter web | `https://bizigniter.app/login` | 200 |
| companero-ai (intern) | `http://companero-ai-engine-app-vtycag-api-1:8100/healthz` | 200 — prin dokploy-network; public dă 403 (WAF CF permite doar IP-ul Netcup) |
| status (self) | — uptime-kuma se monitorizează greu singur; opțional monitor extern gratuit (healthchecks.io) | — |

## Notificare

- Tip: **Slack** — folosește webhook-ul existent al Companero core (același canal cu
  alertele data-health). Se configurează o singură dată în uptime-kuma → Settings →
  Notifications, apoi se bifează „Default enabled" ca toate monitoarele s-o moștenească.

## De făcut (rămas din B3)

- [x] Monitoarele — CONFIGURATE 2026-07-18, 12/12 UP.
- [x] Notificare — email Brevo default pe toate (Slack rămâne opțional, cere incoming webhook).
- [ ] Sentry: cont + câte un DSN pentru Bizigniter, Facturare, CRM (SaaS free tier
      ajunge); env `SENTRY_DSN` per app + SDK-urile — sesiune separată.
