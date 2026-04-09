const yearNode = document.getElementById("year");

if (yearNode) {
  yearNode.textContent = String(new Date().getFullYear());
}

const demoConfig = {
  idle: {
    expanded: true,
    mini: "Panel preview",
    title: "Session overview",
    subtitle: "Preview how Ping Island expands when multiple sessions need attention.",
    badge: "IDLE",
    actions: [],
    activeSession: "codex",
    event: "Codex",
    thread: "Placeholder session title",
    copy: "Placeholder preview copy for the active session row."
  },
  approval: {
    expanded: true,
    mini: "Approval required",
    title: "Approve tool call",
    subtitle: "Claude Code wants permission to run a shell command.",
    badge: "ACTION",
    actions: ["Approve", "Deny"],
    activeSession: "claude",
    event: "Claude Code",
    thread: "Placeholder approval request",
    copy: "Placeholder answer preview for an approval state."
  },
  question: {
    expanded: true,
    mini: "Question waiting",
    title: "Answer follow-up",
    subtitle: "Codex needs a quick product decision before continuing.",
    badge: "INPUT",
    actions: ["Reply", "Open session"],
    activeSession: "gemini",
    event: "Qoder",
    thread: "Placeholder question state",
    copy: "Placeholder assistant reply preview for a question state."
  },
  complete: {
    expanded: true,
    mini: "Task completed",
    title: "Session completed",
    subtitle: "CodeBuddy finished and the summary is ready for review.",
    badge: "DONE",
    actions: ["View summary", "Jump back"],
    activeSession: "complete",
    event: "CodeBuddy",
    thread: "Placeholder completion state",
    copy: "Placeholder completion summary preview."
  }
};

const chips = Array.from(document.querySelectorAll("[data-demo-state]"));
const notch = document.querySelector("[data-demo-notch]");
const shell = document.querySelector("[data-demo-shell]");
const sessionRows = Array.from(document.querySelectorAll("[data-session]"));

const fields = {
  mini: document.querySelector("[data-demo-mini]"),
  title: document.querySelector("[data-demo-title]"),
  subtitle: document.querySelector("[data-demo-subtitle]"),
  badge: document.querySelector("[data-demo-badge]"),
  thread: document.querySelector("[data-demo-thread]"),
  copy: document.querySelector("[data-demo-copy]"),
  event: document.querySelector("[data-demo-event]"),
  actions: document.querySelector("[data-demo-actions]")
};

let currentState = "idle";

function renderDemo(stateKey) {
  const state = demoConfig[stateKey];
  if (!state || !notch) return;

  currentState = stateKey;
  notch.className = `demo-notch ${state.expanded ? "is-expanded " : ""}is-${stateKey}`;
  shell?.classList.toggle("is-expanded", state.expanded);

  fields.mini.textContent = state.mini;
  fields.title.textContent = state.title;
  fields.subtitle.textContent = state.subtitle;
  fields.badge.textContent = state.badge;
  fields.thread.textContent = state.thread;
  fields.copy.textContent = state.copy;
  fields.event.textContent = state.event;
  fields.actions.innerHTML = state.actions
    .map((action) => `<span class="demo-action-pill">${action}</span>`)
    .join("");

  sessionRows.forEach((row) => {
    row.classList.toggle("is-active", row.dataset.session === state.activeSession);
  });

  chips.forEach((chip) => {
    const active = chip.dataset.demoState === stateKey;
    chip.classList.toggle("is-active", active);
    chip.setAttribute("aria-pressed", active ? "true" : "false");
  });
}

chips.forEach((chip) => {
  chip.addEventListener("click", () => renderDemo(chip.dataset.demoState));
});

if (notch) {
  notch.addEventListener("click", () => {
    const nextState = {
      idle: "approval",
      approval: "question",
      question: "complete",
      complete: "idle"
    }[currentState] || "idle";

    renderDemo(nextState);
  });
}

renderDemo("idle");

async function refreshStars() {
  try {
    const response = await fetch("https://api.github.com/repos/erha19/ping-island", {
      headers: {
        Accept: "application/vnd.github+json"
      }
    });

    if (!response.ok) return;

    const repo = await response.json();
    const stars = typeof repo.stargazers_count === "number" ? repo.stargazers_count : null;

    if (stars === null) return;

    document.querySelectorAll("[data-stars]").forEach((node) => {
      node.textContent = String(stars);
    });
  } catch {
    // Keep fallback count when API is unavailable.
  }
}

refreshStars();
