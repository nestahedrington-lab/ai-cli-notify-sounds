import { spawn } from "node:child_process";

const SOURCE = "OpenCode";
const THROTTLE_MS = 1500;
const recentEvents = new Map();
const IS_WINDOWS = process.platform === "win32";

function homeDir() {
  return process.env.HOME || process.env.USERPROFILE || "";
}

function windowsNotifyScript() {
  const localAppData =
    process.env.LOCALAPPDATA ||
    (process.env.USERPROFILE
      ? `${process.env.USERPROFILE}\\AppData\\Local`
      : "");
  return `${localAppData}\\ai-notify\\bin\\opencode-notify.ps1`;
}

function notifyCommand(payload) {
  if (IS_WINDOWS) {
    return {
      command: process.env.AI_NOTIFY_POWERSHELL || "powershell.exe",
      args: [
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        windowsNotifyScript(),
        SOURCE,
      ],
      stdin: JSON.stringify(payload),
    };
  }

  return {
    command: `${homeDir()}/.local/bin/opencode-notify.sh`,
    args: [SOURCE],
    stdin: JSON.stringify(payload),
  };
}

function eventSessionID(event) {
  return event?.properties?.sessionID || event?.id || "unknown";
}

function errorMessage(error) {
  if (!error) return "OpenCode session failed";
  if (typeof error === "string") return error;
  return error.message || error.type || JSON.stringify(error);
}

function attentionMessage(input, fallback) {
  if (!input) return fallback;
  if (typeof input === "string") return input;
  return (
    input.message ||
    input.title ||
    input.tool ||
    input.type ||
    input.id ||
    fallback
  );
}

function shouldThrottle(key) {
  const now = Date.now();
  const last = recentEvents.get(key) || 0;
  if (now - last < THROTTLE_MS) return true;
  recentEvents.set(key, now);
  return false;
}

function notify(payload) {
  const command = notifyCommand(payload);
  const child = spawn(command.command, command.args, {
    stdio: ["pipe", "ignore", "ignore"],
    detached: true,
    windowsHide: true,
  });

  child.stdin.end(command.stdin);
  child.unref();
}

export async function OpenCodeNotifyPlugin({ directory }) {
  return {
    "permission.ask": async (input) => {
      const sessionID = input?.sessionID || "unknown";
      const key = `${sessionID}:permission:${input?.id || input?.tool || "ask"}`;
      if (shouldThrottle(key)) return;

      notify({
        source: SOURCE,
        hook_event_name: "Notification",
        notification_type: "permission_prompt",
        cwd: directory,
        title: "OpenCode needs permission",
        message: attentionMessage(input, "OpenCode needs permission"),
      });
    },

    event: async ({ event }) => {
      const sessionID = eventSessionID(event);

      if (event.type === "question.asked") {
        const key = `${sessionID}:question:${event.id || "asked"}`;
        if (shouldThrottle(key)) return;

        notify({
          source: SOURCE,
          hook_event_name: "Notification",
          notification_type: "elicitation_dialog",
          cwd: directory,
          title: "OpenCode needs input",
          message: attentionMessage(
            event?.properties,
            "OpenCode needs input"
          ),
        });
        return;
      }

      if (
        event.type === "session.error" ||
        event.type === "session.next.step.failed"
      ) {
        const key = `${sessionID}:error`;
        if (shouldThrottle(key)) return;

        notify({
          source: SOURCE,
          hook_event_name: "StopFailure",
          cwd: directory,
          last_assistant_message: errorMessage(event?.properties?.error),
        });
        return;
      }

      if (event.type === "session.idle") {
        const key = `${sessionID}:idle`;
        if (shouldThrottle(key)) return;

        notify({
          source: SOURCE,
          hook_event_name: "Stop",
          cwd: directory,
          last_assistant_message: "OpenCode session completed",
        });
      }
    },
  };
}

export const server = OpenCodeNotifyPlugin;
