# Monitorizare — uptime-kuma (status.companero.ro)

Instanța: proiect Dokploy `Monitoring`, `https://status.companero.ro` (cont admin: Marian).
uptime-kuma nu are API REST oficial (config prin UI / socket.io) — lista de mai jos e
sursa de adevăr pentru monitoarele de adăugat manual (sau printr-o sesiune viitoare cu
`uptime-kuma-api` din python, cu credențialele lui Marian).

## Monitoare de adăugat (HTTP(s), keyword unde e notat, interval 60s)

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
| companero-ai | `https://ai.companero.ro/healthz` | 200 (prin tunelul CF; dacă e gated, monitor intern) |
| status (self) | — uptime-kuma se monitorizează greu singur; opțional monitor extern gratuit (healthchecks.io) | — |

## Notificare

- Tip: **Slack** — folosește webhook-ul existent al Companero core (același canal cu
  alertele data-health). Se configurează o singură dată în uptime-kuma → Settings →
  Notifications, apoi se bifează „Default enabled" ca toate monitoarele s-o moștenească.

## De făcut (rămas din B3)

- [ ] Adăugarea monitoarelor de mai sus (Marian în UI sau sesiune cu uptime-kuma-api).
- [ ] Notificarea Slack (webhook-ul din config-ul core — vezi env-urile de pe Netcup).
- [ ] Sentry: cont + câte un DSN pentru Bizigniter, Facturare, CRM (SaaS free tier
      ajunge); env `SENTRY_DSN` per app + SDK-urile — sesiune separată.
