# Ecosistem Companero — utilitare cross-proiect
# Necesită `just` (brew install just). Rulează de oriunde: `just -f ~/docker/altia/ecosystem/justfile <cmd>`

altia := justfile_directory() / ".."
facturare_compose := altia / "companero.facturare/infra/docker-compose.local.yml"

default:
    @just --list

# ── Companero ID (Zitadel local partajat, canonic pe :8082) ──────────────────
# Azi instanța trăiește în compose-ul Facturare (vezi docs/medii-zitadel.md).

idp-up:
    docker compose -f "{{facturare_compose}}" up -d zitadel-db zitadel
    @echo "Zitadel local: http://localhost:8082 (admin@facturare.local)"

idp-down:
    docker compose -f "{{facturare_compose}}" stop zitadel zitadel-db

idp-status:
    @docker compose -f "{{facturare_compose}}" ps zitadel zitadel-db 2>/dev/null || echo "IdP oprit."
    @curl -sf http://localhost:8082/debug/healthz >/dev/null 2>&1 && echo "healthz: OK" || echo "healthz: indisponibil"

# ── Stadiul repo-urilor (git status scurt peste tot) ─────────────────────────

status:
    #!/usr/bin/env bash
    for d in docker-companies/src/companies companero-ai companero-mobile companero.crm companero.facturare datero bizigniter ansible_automation ecosystem; do
      echo "== $d"
      git -C "{{altia}}/$d" status -sb 2>/dev/null | head -5 || echo "(fără git aici)"
    done
