# Serverul Hetzner (88.99.96.16) — reziliență & întreținere

Configurat 2026-07-19 (aprobat de Marian). SSH: `altia@88.99.96.16` (docker fără sudo).
Totul rulează din **crontab-ul userului `altia`** (`crontab -l`), scripturile în
`/home/altia/bin/`, log-urile în `/home/altia/*.log`.

## 1. Backup-ul stării Dokploy — zilnic 03:00 UTC

`~/bin/dokploy-state-backup.sh` → `s3://backups/dokploy-panel/dokploy-state-<TS>.tar.gz`
(tokenul R2 scoped din `~/.r2-backups.env`, 600; retenție 14). Conține:
- `dokploy-db.dump` — baza panel-ului (pg_dump custom din `dokploy-postgres`): toate
  proiectele, aplicațiile, **env-urile/secretele**, domeniile, destinațiile, backup-urile.
- `etc-dokploy.tar.gz` — `/etc/dokploy` fără logs (traefik dynamic + acme.json,
  compose-urile scrise, codul clonat al aplicațiilor) — ~450 MB.
- volumele mici critice: machinekey Zitadel prod+staging (PAT-urile), datele uptime-kuma
  (monitoare/notificări).

Verificat la instalare: upload OK, arhiva descărcată + extrasă local, `pg_restore --list`
pe dump valid. **Restore de dezastru (schiță)**: server nou cu Dokploy instalat → oprești
panel-ul → restaurezi dump-ul în dokploy-postgres + dezarhivezi /etc/dokploy → pornești;
aplicațiile se re-deployează din git (imaginile nu se salvează — se reconstruiesc).

## 2. Curățenia Docker — zilnic 04:30 UTC

Incidentul care a motivat-o: disk plin din imagini acumulate. Cron:
`docker image prune -af --filter "until=72h"` + `docker builder prune -af
--keep-storage=10GB` (log: `~/docker-cleanup.log`). Compromis asumat: imaginile mai vechi
de 72h dispar → rollback-ul instant la o imagine anterioară nu mai există, dar Dokploy
reconstruiește din git în minute. **Volumele NU se ating niciodată automat.**
Prima rulare a recuperat ~19 GB (disk 67%→65%).

## 3. Monitorizarea serverului — heartbeat inversat prin uptime-kuma

`~/bin/host-health-push.sh` (cron la 5 min) face ping către monitoarele PUSH din kuma
**doar când metrica e OK** — lipsa ping-ului = DOWN = email:

| Monitor | Condiția de „OK" |
|---|---|
| Hetzner: disk <85% | utilizare `/` sub 85% |
| Hetzner: load OK | load5 < 2×nr. core-uri |
| Hetzner: RAM OK | RAM disponibil > 10% |

Toate trei verificate UP la instalare (disk 68%, load 0.47, RAM avail 81%).
Dacă schimbi pragurile: editezi scriptul pe server (token-urile push sunt în el).

## Limitări cunoscute / viitor

- Serverul rămâne single point of failure ca HARDWARE — backup-urile permit
  reconstrucție, nu failover. (Failover-ul real = alt server + restore, câteva ore.)
- Netdata/dashboard-uri de metrici: opțional, dacă alertele nu ajung.
- Backup-ul stării Dokploy NU salvează imaginile Docker (by design).
