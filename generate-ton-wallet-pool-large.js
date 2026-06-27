const fs = require("fs");
const path = require("path");

function readNumber(name, fallback, min, max) {
  const raw = Number(process.env[name] || fallback);
  if (!Number.isFinite(raw)) return fallback;
  return Math.max(min, Math.min(max, Math.floor(raw)));
}

const shardCount = readNumber("PAYMENT_SCANNER_SHARD_COUNT", 64, 1, 256);
const batchSize = readNumber("PAYMENT_SCAN_BATCH_SIZE", 250, 1, 1000);
const concurrency = readNumber("PAYMENT_SCAN_CONCURRENCY", 16, 1, 64);
const intervalMs = readNumber("PAYMENT_SCAN_INTERVAL_MS", 5000, 2000, 300000);
const jitterMs = readNumber("PAYMENT_SCAN_JITTER_MS", 2500, 0, 60000);

function serviceYaml(index) {
  return `  - type: worker
    name: vidipay-payment-scanner-100x-${index}
    runtime: node
    plan: standard
    buildCommand: npm ci --omit=dev
    startCommand: npm run start:scanner
    envVars:
      - key: NODE_ENV
        value: production
      - key: WORKER_MODE
        value: scanner
      - key: PAYMENT_SCANNER_ENABLED
        value: true
      - key: PAYMENT_SCANNER_WORKER_ID
        value: scanner-100x-${index}
      - key: PAYMENT_SCANNER_SHARD_COUNT
        value: ${shardCount}
      - key: PAYMENT_SCANNER_SHARD_INDEX
        value: ${index}
      - key: PAYMENT_SCAN_INTERVAL_MS
        value: ${intervalMs}
      - key: PAYMENT_SCAN_BATCH_SIZE
        value: ${batchSize}
      - key: PAYMENT_SCAN_CONCURRENCY
        value: ${concurrency}
      - key: PAYMENT_SCAN_JITTER_MS
        value: ${jitterMs}
      - key: RATE_LIMIT_BACKEND
        value: memory
      - key: TONAPI_BASE_URL
        value: https://tonapi.io
      - key: SUPABASE_URL
        sync: false
      - key: SUPABASE_SERVICE_ROLE_KEY
        sync: false
      - key: TONAPI_KEY
        sync: false`;
}

const yaml = [
  "# VidiPay 100x scanner worker blueprint.",
  "# Generated file. Create all services or split them across Render accounts/regions.",
  "services:",
  ...Array.from({ length: shardCount }, (_, index) => serviceYaml(index))
].join("\n");

const output = path.resolve(__dirname, "..", "render.100x-64-workers.yaml");
fs.writeFileSync(output, `${yaml}\n`);
console.log(`wrote ${output}`);
