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
const confettiColors = ["#fff3d9", "#ffd86b", "#ffb05c", "#ff7a59", "#ffe6f4"];
let submitCelebrateTimeout = null;

function setSubmitReady(isReady) {
  if (!submitBtn) return;

  submitBtn.classList.toggle("is-ready", isReady);
  submitBtn.disabled = !isReady;
  submitBtn.setAttribute("aria-disabled", String(!isReady));
}

function triggerSubmitConfetti(button) {
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

  const rect = button.getBoundingClientRect();
  const originX = rect.left + rect.width / 2;
  const originY = rect.top + rect.height / 2;
  const confettiLayer = document.createElement("div");

  confettiLayer.className = "desktop-demo-confetti";

  for (let index = 0; index < 18; index += 1) {
    const particle = document.createElement("span");
    const angle = (-90 + (160 / 17) * index + (Math.random() * 18 - 9)) * (Math.PI / 180);
    const distance = 52 + Math.random() * 40;
    const drift = Math.random() * 22 - 11;

    particle.className = "desktop-demo-confetti-piece";
    if (index % 3 === 0) {
      particle.classList.add("is-dot");
    }

    particle.style.setProperty("--origin-x", `${originX}px`);
    particle.style.setProperty("--origin-y", `${originY}px`);
    particle.style.setProperty("--travel-x", `${Math.cos(angle) * distance}px`);
    particle.style.setProperty("--travel-y", `${Math.sin(angle) * distance - 18}px`);
    particle.style.setProperty("--spin", `${drift + (Math.random() > 0.5 ? 1 : -1) * (180 + Math.random() * 140)}deg`);
    particle.style.setProperty("--confetti-color", confettiColors[index % confettiColors.length]);
    particle.style.animationDelay = `${Math.random() * 90}ms`;
    particle.style.opacity = "0";
    confettiLayer.appendChild(particle);
  }

  document.body.appendChild(confettiLayer);
  window.setTimeout(() => confettiLayer.remove(), 1100);
}

if (choiceGrid && submitBtn) {
  setSubmitReady(false);

  choiceGrid.addEventListener("click", (e) => {
    const choice = e.target.closest(".desktop-demo-choice");
    if (!choice) return;

    choiceGrid.querySelectorAll(".desktop-demo-choice").forEach((c) => c.classList.remove("is-active"));
    choice.classList.add("is-active");
    setSubmitReady(true);
  });

  submitBtn.addEventListener("click", () => {
    if (submitBtn.disabled) return;

    submitBtn.classList.remove("is-celebrating");
    void submitBtn.offsetWidth;
    submitBtn.classList.add("is-celebrating");

    if (submitCelebrateTimeout) {
      window.clearTimeout(submitCelebrateTimeout);
    }

    submitCelebrateTimeout = window.setTimeout(() => {
      submitBtn.classList.remove("is-celebrating");
    }, 540);

    triggerSubmitConfetti(submitBtn);
  });
}
