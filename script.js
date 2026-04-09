const yearNode = document.getElementById("year");

if (yearNode) {
  yearNode.textContent = String(new Date().getFullYear());
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
