const yearNode = document.getElementById("year");

if (yearNode) {
  yearNode.textContent = String(new Date().getFullYear());
}

const desktopDemo = document.querySelector("[data-desktop-demo]");

if (desktopDemo) {
  window.setTimeout(() => {
    desktopDemo.classList.remove("is-collapsed");
    desktopDemo.classList.add("is-expanded");
  }, 3000);
}

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

/* Choice grid: click to select, light up submit button */
const choiceGrid = document.querySelector(".desktop-demo-choice-grid");
const submitBtn = document.querySelector(".desktop-demo-submit");

if (choiceGrid && submitBtn) {
  choiceGrid.addEventListener("click", (e) => {
    const choice = e.target.closest(".desktop-demo-choice");
    if (!choice) return;

    choiceGrid.querySelectorAll(".desktop-demo-choice").forEach((c) => c.classList.remove("is-active"));
    choice.classList.add("is-active");
    submitBtn.classList.add("is-ready");
  });
}
