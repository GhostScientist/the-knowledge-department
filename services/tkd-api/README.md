# TKD API Service Scaffold

## Purpose

This folder is the starting point for the product-layer service that receives agent events and governed knowledge assertions.

Current repo behavior still uses `scripts/mock_tkd_server.py`. This folder defines the shape of the real service implementation.

## Scope

Initial endpoints expected by `knowledge` CLI:

- `GET /healthz`
- `POST /v1/agents/events`
- `POST /v1/knowledge/assertions`
- `POST /v1/knowledge/promotions`
- `GET /v1/knowledge/assertions/current`
- `GET /v1/knowledge/assertions/{assertion_id}/timeline`

## Files

- `api/openapi.yaml`: endpoint contract scaffold.
- `config/example.env`: expected runtime configuration variables.
- `TASKS.md`: implementation checklist for this service.

## Local Development

Until the real service exists, use the existing mock backend:

```bash
python3 scripts/mock_tkd_server.py --host 127.0.0.1 --port 8787
```

And test with:

```bash
./scripts/smoke-test.sh --online
```
