const yearNode = document.getElementById("year");

if (yearNode) {
  yearNode.textContent = String(new Date().getFullYear());
}

const demoConfig = {
  idle: {
    expanded: false,
    badge: "IDLE",
    mini: "No pending actions",
    title: "Quiet mode",
    subtitle: "No approvals or questions waiting.",
    thread: "Codex thread synced",
    copy: "Ping Island stays small until the run actually needs you.",
    focus: "Ghostty / tmux / Cursor",
    event: "Quiet state",
    actions: []
  },
  approval: {
    expanded: true,
    badge: "ACTION",
    mini: "Approval required",
    title: "Approve tool call",
    subtitle: "Claude Code wants permission to run a shell command.",
    thread: "Claude Code / tool approval",
    copy: "Approve from the notch, then jump back only if the workspace matters.",
    focus: "iTerm2 / tmux pane 2",
    event: "Shell approval waiting",
    actions: ["Approve", "Deny"]
  },
  question: {
    expanded: true,
    badge: "INPUT",
    mini: "Question waiting",
    title: "Answer follow-up",
    subtitle: "Codex needs a quick product decision before continuing.",
    thread: "Codex / ask-user question",
    copy: "Reply inline and keep the run moving without tab hunting.",
    focus: "Cursor / project window",
    event: "User input requested",
    actions: ["Reply", "Open session"]
  },
  complete: {
    expanded: true,
    badge: "DONE",
    mini: "Task completed",
    title: "Session completed",
    subtitle: "Gemini CLI finished and is ready for review.",
    thread: "Gemini CLI / completed task",
    copy: "The notch can hold the summary long enough for you to decide what to do next.",
    focus: "Ghostty / latest session",
    event: "Completion summary ready",
    actions: ["View summary", "Jump back"]
  }
};

const chips = Array.from(document.querySelectorAll("[data-demo-state]"));
const notch = document.querySelector("[data-demo-notch]");
const fields = {
  mini: document.querySelector("[data-demo-mini]"),
  title: document.querySelector("[data-demo-title]"),
  subtitle: document.querySelector("[data-demo-subtitle]"),
  badge: document.querySelector("[data-demo-badge]"),
  thread: document.querySelector("[data-demo-thread]"),
  copy: document.querySelector("[data-demo-copy]"),
  focus: document.querySelector("[data-demo-focus]"),
  event: document.querySelector("[data-demo-event]"),
  actions: document.querySelector("[data-demo-actions]")
};

let currentState = "idle";

function renderDemo(stateKey) {
  const state = demoConfig[stateKey];
  if (!state || !notch) return;

  currentState = stateKey;
  notch.classList.toggle("is-expanded", state.expanded);
  notch.className = `demo-notch ${state.expanded ? "is-expanded " : ""}is-${stateKey}`;

  fields.mini.textContent = state.mini;
  fields.title.textContent = state.title;
  fields.subtitle.textContent = state.subtitle;
  fields.badge.textContent = state.badge;
  fields.thread.textContent = state.thread;
  fields.copy.textContent = state.copy;
  fields.focus.textContent = state.focus;
  fields.event.textContent = state.event;
  fields.actions.innerHTML = state.actions
    .map((action) => `<span class="demo-action-pill">${action}</span>`)
    .join("");

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
    if (currentState === "idle") {
      renderDemo("approval");
      return;
    }

    const nextState = {
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
    // Keep fallback count when the API is unavailable.
  }
}

refreshStars();
