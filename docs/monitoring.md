# Monitorizare — uptime-kuma (status.companero.ro)

Instanța: proiect Dokploy `Monitoring`, `https://status.companero.ro` (cont admin: Marian;
credențiale local pe Mac în `~/.secrets/uptime-kuma`). **CONFIGURAT 2026-07-18 prin
`uptime-kuma-api`** (venv + script în scratchpad-ul sesiunii; pattern reutilizabil):
12 monitoare, toate UP la configurare, interval 60s, retry 2, notificare email
**Brevo → marian.dobre@gmail.com** setată default pe toate (Slack: de adăugat când
există un incoming webhook — bot-token-ul core nu e compatibil cu uptime-kuma).

**Versiune: 2.5.11 (din 2026-11-12; înainte `louislam/uptime-kuma:1` = 1.23.17, linie fără
patch-uri).** Aplicația Dokploy `uptime-kuma` (serviciul swarm `app-calculate-virtual-feed-zbqmey`,
sursă *docker*, volum `uptime-kuma-data` → `/app/data`), imagine fixată pe tag exact. Upgrade
1→2: repetiție pe o copie a volumului (`--network none`, ca să nu plece notificări), apoi
serviciul scalat la 0, backup, imaginea schimbată în DB-ul Dokploy (`application.dockerImage`)
și în serviciu; migrarea agregatelor a durat ~3,5 min (322 MB de date). Backup v1:
`/home/altia/pre-kuma-v2-20261112/` pe Hetzner. **Update order = `stop-first` (din 2026-11-13)**,
setat în DB-ul Dokploy (`application.updateConfigSwarm`, înainte NULL = implicitul Dokploy
`start-first`) și pe serviciu: la redeploy nu mai pornesc două instanțe pe același `kuma.db`
(SQLite); costul e o întrerupere de câteva secunde. La un upgrade major, tot backup întâi. Notificarea email nu are
template personalizat, deci trecerea v2 la LiquidJS nu o afectează. La un upgrade viitor:
tag nou în Dokploy (Docker image) + Deploy; citește întâi release notes.

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
