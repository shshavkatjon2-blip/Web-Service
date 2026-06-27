const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const server = fs.readFileSync(path.join(root, "server.js"), "utf8");

const required = [
  ["BACKEND_VERSION", "v1.8.1-hyperscale-backpressure-20260627"],
  ["OPS_DB_AUDIT_TIMEOUT_MS", "OPS_DB_AUDIT_TIMEOUT_MS"],
  ["SCALE_AUDIT_COUNT_MODE", "SCALE_AUDIT_COUNT_MODE"],
  ["/ops/scanner-shards", 'app.get("/ops/scanner-shards"'],
  ["/ops/scanner-backlog", 'app.get("/ops/scanner-backlog"'],
  ["/ops/wallet-capacity", 'app.get("/ops/wallet-capacity"'],
  ["/ops/redis", 'app.get("/ops/redis"'],
  ["/ops/ton-signer", 'app.get("/ops/ton-signer"'],
  ["/ops/final-gate", 'app.get("/ops/final-gate"'],
  ["/ops/scale-contract", 'app.get("/ops/scale-contract"'],
  ["redis health helper", "checkRedisHealth"],
  ["ton signer readiness helper", "buildTonSignerReadinessReport"],
  ["1.5M signer required flag", "REQUIRE_TON_AUTO_PAYOUT_FOR_1_5M"],
  ["final launch gate helper", "buildFinalLaunchGate"],
  ["wallet capacity helper", "buildWalletCapacityReport"],
  ["scanner backlog helper", "buildScannerBacklogReport"],
  ["scanner shard helper", "buildScannerShardReport"],
  ["scale contract helper", "buildScaleContract"],
  ["ops timeout helper", "withOpsTimeout"],
  ["planned count mode", "planned"]
];

const errors = [];
for (const [label, pattern] of required) {
  if (!server.includes(pattern)) errors.push(`server.js missing ${label}`);
}

if (errors.length) {
  console.error("SCALE CONTRACT CHECK FAILED");
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log("SCALE CONTRACT CHECK OK");
console.log("endpoints=/ops/scanner-shards,/ops/scanner-backlog,/ops/wallet-capacity,/ops/redis,/ops/ton-signer,/ops/final-gate,/ops/scale-contract");
