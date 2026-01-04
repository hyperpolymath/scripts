#!/usr/bin/env bash
set -euo pipefail

say() { printf "\n==> %s\n" "$*"; }

need() {
  local var="$1" prompt="$2" secret="${3:-false}"
  if [[ "${secret}" == "true" ]]; then
    read -r -s -p "${prompt}: " "${var}"; echo
  else
    read -r -p "${prompt}: " "${var}"
  fi
  if [[ -z "${!var}" ]]; then
    echo "Missing: ${var}" >&2
    exit 1
  fi
}

say "Cloudflare Workers + ReScript bootstrap"

need APP_SLUG "Worker name (e.g. git-eco-bot-hook)"
need CF_ACCOUNT_ID "Cloudflare Account ID"
need WEBHOOK_SECRET "GitHub Webhook Secret (you already generated one)" true

# optional bits
read -r -p "Create GitHub Actions deploy workflow too? (y/N): " WITH_GHA
WITH_GHA="${WITH_GHA:-N}"

say "Creating project: ${APP_SLUG}"
mkdir -p "${APP_SLUG}"
cd "${APP_SLUG}"

# Basic files
mkdir -p src docs
cat > docs/README.adoc <<'ADOC'
= Git Eco Bot — Webhook Receiver (Workers)
:toc:

== What this is
A Cloudflare Worker webhook receiver for a GitHub App (Installation/Webhook mode).

== Environment
* `GITHUB_WEBHOOK_SECRET` — webhook HMAC secret
* Cloudflare bindings via `wrangler.jsonc`

== Local dev
. Install deps: `npm i` (wrangler) and `npm i -D rescript`
. Build: `npx rescript build -w`
. Run worker dev: `npx wrangler dev`

== Deploy
`npx wrangler deploy`

== GitHub App setup (manual)
. Create GitHub App
. Set webhook URL to `https://<your-worker>.<your-subdomain>.workers.dev/github/webhook`
. Set webhook secret to match `GITHUB_WEBHOOK_SECRET`
. Subscribe to `Issues` / `Pull request` events (or what you need)
ADOC

# ReScript config (minimal)
cat > bsconfig.json <<'JSON'
{
  "name": "git-eco-bot-worker",
  "sources": [{ "dir": "src", "subdirs": true }],
  "package-specs": { "module": "esmodule", "in-source": false },
  "suffix": ".mjs",
  "bs-dependencies": [],
  "warnings": {
    "error": "+101"
  }
}
JSON

# Worker entrypoint (tiny JS shim importing ReScript output)
mkdir -p dist
cat > dist/worker.mjs <<'JS'
import { handleFetch } from "../lib/es6/src/Webhook.mjs";

export default {
  async fetch(request, env, ctx) {
    return handleFetch(request, env, ctx);
  }
};
JS

# ReScript webhook handler (WebCrypto HMAC verify + routing)
cat > src/Webhook.res <<'RES'
let textEncoder = TextEncoder.make()

let toHex = (buf: Js.TypedArray2.ArrayBuffer.t): string => {
  let u8 = Js.TypedArray2.Uint8Array.fromBuffer(buf)
  let len = Js.TypedArray2.Uint8Array.length(u8)
  let parts = Belt.Array.make(len, "")
  for i in 0 to len - 1 {
    let b = Js.TypedArray2.Uint8Array.unsafe_get(u8, i)
    let h = Js.Int.toStringAs(~base=16, b)->Js.String2.padStart(2, "0")
    parts[i] = h
  }
  parts->Belt.Array.joinWith("")
}

let timingSafeEq = (a: string, b: string): bool => {
  if a->Js.String2.length != b->Js.String2.length { false } else {
    // constant-ish time compare in JS string space
    let mutable diff = 0
    for i in 0 to a->Js.String2.length - 1 {
      diff = diff lor ((a->Js.String2.charCodeAt(i)) lxor (b->Js.String2.charCodeAt(i)))
    }
    diff == 0
  }
}

let verifySignature = async (~secret: string, ~body: Js.TypedArray2.ArrayBuffer.t, ~sigHeader: option<string>) => {
  switch sigHeader {
  | None => false
  | Some(h) =>
    // Expect "sha256=..."
    if !Js.String2.startsWith(h, "sha256=") { false } else {
      let expected = h->Js.String2.sliceToEnd(7)
      let keyData = textEncoder->TextEncoder.encode(secret)
      let algo: Js.Json.t = %raw(`({ name: "HMAC", hash: "SHA-256" })`)
      let key =
        await Webcrypto.Subtle.importKey(
          "raw",
          keyData->Js.TypedArray2.Uint8Array.buffer,
          algo,
          false,
          ["sign"],
        )
      let sig = await Webcrypto.Subtle.sign("HMAC", key, body)
      let actual = toHex(sig)
      timingSafeEq(actual, expected)
    }
  }
}

let bad = (msg: string) =>
  Response.makeWithInit(
    msg,
    {
      "status": 401,
      "headers": HeadersInit.makeWithArray([("content-type", "text/plain")]),
    },
  )

let ok = (msg: string) =>
  Response.makeWithInit(
    msg,
    {
      "status": 200,
      "headers": HeadersInit.makeWithArray([("content-type", "text/plain")]),
    },
  )

let notFound = () =>
  Response.makeWithInit(
    "not found",
    { "status": 404, "headers": HeadersInit.makeWithArray([("content-type", "text/plain")]) },
  )

@val external consoleLog: 'a => unit = "console.log"

let handleFetch = async (request: Request.t, env: 'env, _ctx: 'ctx): Promise.t<Response.t> => {
  let url = URL.make(request["url"])

  if url["pathname"] != "/github/webhook" {
    Promise.resolve(notFound())
  } else {
    let secret: option<string> = %raw(`env && env.GITHUB_WEBHOOK_SECRET ? env.GITHUB_WEBHOOK_SECRET : null`)
    switch secret {
    | None => Promise.resolve(bad("missing env.GITHUB_WEBHOOK_SECRET"))
    | Some(secret) =>
      let sigHeader = request["headers"]->Headers.get("X-Hub-Signature-256")
      let eventName = request["headers"]->Headers.get("X-GitHub-Event")->Belt.Option.getWithDefault("unknown")
      let delivery = request["headers"]->Headers.get("X-GitHub-Delivery")->Belt.Option.getWithDefault("")

      // IMPORTANT: read raw bytes
      let! bodyBuf = request->Request.arrayBuffer
      let! verified = verifySignature(~secret, ~body=bodyBuf, ~sigHeader)

      if !verified {
        Promise.resolve(bad("bad signature"))
      } else {
        // Minimal routing: just log + acknowledge
        consoleLog({ "event": eventName, "delivery": delivery })
        Promise.resolve(ok("ok"))
      }
    }
  }
}
RES

# Wrangler config (Workers)
cat > wrangler.jsonc <<JSONC
{
  "name": "${APP_SLUG}",
  "main": "dist/worker.mjs",
  "compatibility_date": "2025-12-25",
  "account_id": "${CF_ACCOUNT_ID}"
}
JSONC

# package.json (kept minimal; uses npm only for wrangler/rescript tooling)
cat > package.json <<'JSON'
{
  "name": "git-eco-bot-worker",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "rescript build",
    "dev": "rescript build -w",
    "wrangler:dev": "wrangler dev",
    "deploy": "rescript build && wrangler deploy"
  },
  "devDependencies": {
    "rescript": "^11.1.0",
    "wrangler": "^3.0.0"
  }
}
JSON

# Optional GitHub Actions workflow
if [[ "${WITH_GHA}" == "y" || "${WITH_GHA}" == "Y" ]]; then
  mkdir -p .github/workflows
  cat > .github/workflows/deploy-workers.yml <<'YML'
name: deploy-workers
on:
  push:
    branches: [ "main" ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: "20"

      - run: npm ci || npm install
      - run: npm run deploy
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          # wrangler uses account_id from wrangler.jsonc; token must have Workers deploy permissions
YML

  say "Added GitHub Actions workflow."
  say "You'll need to set repo secret: CLOUDFLARE_API_TOKEN"
fi

say "Installing deps…"
npm install

say "Setting Workers secret (wrangler will prompt)…"
npx wrangler secret put GITHUB_WEBHOOK_SECRET <<EOF
${WEBHOOK_SECRET}
EOF

say "Build + Deploy…"
npm run deploy

say "Done."
say "Next: set GitHub App Webhook URL to: https://${APP_SLUG}.<your-subdomain>.workers.dev/github/webhook"
