const yearNode = document.getElementById("year");

if (yearNode) {
  yearNode.textContent = String(new Date().getFullYear());
}

const typingTarget = document.querySelector(".typing-target");
const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

if (typingTarget) {
  const text = typingTarget.getAttribute("data-text") ?? "";

  if (prefersReducedMotion.matches) {
    typingTarget.textContent = text;
  } else {
    let index = 0;

    const tick = () => {
      typingTarget.textContent = text.slice(0, index);
      index += 1;

      if (index <= text.length) {
        window.setTimeout(tick, 46);
      }
    };

    tick();
  }
}
