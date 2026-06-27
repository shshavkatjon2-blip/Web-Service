# Upload this 3M package to Render Web Service only

This package is for the public API service:

- Render service type: Web Service
- Service name: `vidipay-backend`
- Build command: `npm ci --omit=dev`
- Start command: `npm start`
- Health path: `/healthz`
- Required scaling env: `RATE_LIMIT_BACKEND=redis` and real `REDIS_URL`

Do not upload this package to the Background Worker.

Run this SQL in Supabase before the 3M scanner workers:

```text
RUN_3M_SCALING_SQL_2026-06-27.sql
VERIFY_3M_SCALING_SQL_2026-06-27.sql
```

Expected after deploy:

```text
https://vidipay-backend.onrender.com/healthz
version = v1.7.9-3m-sharded-scanner-20260627
```

3M readiness endpoints:

```text
https://vidipay-backend.onrender.com/ops/capacity
https://vidipay-backend.onrender.com/ops/live
https://vidipay-backend.onrender.com/scanner/healthz
```
