# Upload this hyperscale package to Render Web Service only

This package is for the public API service:

- Render service type: Web Service
- Service name: `vidipay-backend`
- Build command: `npm ci --omit=dev`
- Start command: `npm start`
- Health path: `/healthz`
- Required scaling env: `RATE_LIMIT_BACKEND=redis` and real `REDIS_URL`

Do not upload this package to Background Workers.

Run this SQL in Supabase before enabling the hyperscale scanner pool:

```text
RUN_HYPERSCALE_SQL_2026-06-27.sql
VERIFY_HYPERSCALE_SQL_2026-06-27.sql
```

Expected after deploy:

```text
https://vidipay-backend.onrender.com/healthz
version = v1.8.1-hyperscale-backpressure-20260627
```

Readiness endpoints:

```text
https://vidipay-backend.onrender.com/ops/capacity
https://vidipay-backend.onrender.com/ops/live
https://vidipay-backend.onrender.com/ops/scale-plan
https://vidipay-backend.onrender.com/ops/hyperscale
https://vidipay-backend.onrender.com/scanner/healthz
```
