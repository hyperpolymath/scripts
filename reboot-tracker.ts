// scripts/reboot-tracker.ts
import { join } from "https://deno.land/std@0.224.0/path/mod.ts";
import { parseArgs } from "https://deno.land/std@0.224.0/cli/parse_args.ts";

const REASONS = [
  "Planned Maintenance",
  "Security Update",
  "Hardware Issue",
  "OS Update",
  "Unexpected Crash",
  "Software Bug",
  "Migration",
  "Other"
];

const BASE_DIR = "monitoring/reboot-tracker/logs";
const LOG_FILE = join(BASE_DIR, "reboot-reasons.json");
const SNAPSHOT_DIR = join(BASE_DIR, "snapshots");

async function captureLogs(timestamp: string): Promise<string | null> {
  const filename = `snapshot-${timestamp.replace(/[:.]/g, "-")}.log`;
  const filepath = join(SNAPSHOT_DIR, filename);

  console.log(`\nCapturing system logs to ${filename}...`);

  try {
    await Deno.mkdir(SNAPSHOT_DIR, { recursive: true });

    // Capture journalctl and dmesg
    const journalCmd = new Deno.Command("sudo", {
      args: ["journalctl", "-n", "200", "--no-pager"],
    });
    const dmesgCmd = new Deno.Command("sudo", {
      args: ["dmesg", "-T"], // -T for human readable timestamps
    });

    const journalResult = await journalCmd.output();
    const dmesgResult = await dmesgCmd.output();

    const decoder = new TextDecoder();
    const logContent = [
      "=== SYSTEM LOG SNAPSHOT ===",
      `Captured at: ${timestamp}`,
      "",
      "--- journalctl (last 200 lines) ---",
      decoder.decode(journalResult.stdout),
      "",
      "--- dmesg (tail) ---",
      decoder.decode(dmesgResult.stdout).split("\n").slice(-100).join("\n"),
    ].join("\n");

    await Deno.writeTextFile(filepath, logContent);
    return filename;
  } catch (err) {
    console.error(`Warning: Failed to capture system logs: ${err.message}`);
    return null;
  }
}

async function main() {
  const args = parseArgs(Deno.args);
  const isShutdown = args.shutdown === true;
  const actionName = isShutdown ? "SHUTDOWN" : "REBOOT";

  console.log("--------------------------------------------------");
  console.log(`   SYSTEM ${actionName} TRACKER (Server Reason Prompt)   `);
  console.log("--------------------------------------------------");
  console.log(`\nPlease select a reason for the ${actionName}:`);
  REASONS.forEach((reason, i) => {
    console.log(`  [${i + 1}] ${reason}`);
  });

  let selection = "";
  while (true) {
    const input = prompt("\nEnter your choice [1-8]:");
    if (input && Number(input) >= 1 && Number(input) <= REASONS.length) {
      selection = REASONS[Number(input) - 1];
      break;
    }
    console.log("Invalid selection. Please try again.");
  }

  const details = prompt("\nProvide details/comments (optional):") || "No details provided.";

  const timestamp = new Date().toISOString();
  const snapshotFile = await captureLogs(timestamp);

  const logEntry = {
    timestamp: timestamp,
    user: Deno.env.get("USER") || "unknown",
    action: actionName,
    reason: selection,
    details: details,
    hostname: Deno.hostname(),
    snapshot: snapshotFile,
  };

  try {
    let logs = [];
    try {
      const content = await Deno.readTextFile(LOG_FILE);
      logs = JSON.parse(content);
    } catch {
      // File doesn't exist or is empty
    }

    logs.push(logEntry);
    await Deno.writeTextFile(LOG_FILE, JSON.stringify(logs, null, 2));
    console.log(`\nReason and log snapshot recorded in ${BASE_DIR}`);
  } catch (err) {
    console.error(`Error logging reason: ${err.message}`);
    const retry = prompt(`\nContinue with ${actionName} anyway? (y/N):`);
    if (retry?.toLowerCase() !== 'y') {
      console.log("Aborted.");
      Deno.exit(1);
    }
  }

  const confirm = prompt(`\nAre you sure you want to ${actionName} now? (y/N):`);
  if (confirm?.toLowerCase() === 'y') {
    console.log(`Initiating ${actionName}...`);
    const cmd = new Deno.Command("sudo", {
      args: [isShutdown ? "shutdown" : "reboot"],
    });
    await cmd.spawn();
  } else {
    console.log(`${actionName} cancelled. Reason and logs have been recorded.`);
  }
}

main();
