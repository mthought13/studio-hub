// Copy buttons (works on plain http, where navigator.clipboard is unavailable) + download counters.
(function () {
  function copyText(text, btn) {
    function done() {
      var old = btn.textContent;
      btn.textContent = "Скопировано";
      btn.classList.add("ok");
      setTimeout(function () { btn.textContent = old; btn.classList.remove("ok"); }, 1400);
    }
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(text).then(done, function () { fallback(text); done(); });
    } else { fallback(text); done(); }
  }
  function fallback(text) {
    var ta = document.createElement("textarea");
    ta.value = text; ta.setAttribute("readonly", ""); ta.style.position = "fixed"; ta.style.opacity = "0";
    document.body.appendChild(ta); ta.select();
    try { document.execCommand("copy"); } catch (e) {}
    document.body.removeChild(ta);
  }
  document.addEventListener("click", function (ev) {
    var btn = ev.target.closest(".copy");
    if (!btn) return;
    ev.preventDefault();
    if (btn.hasAttribute("data-copy-pre")) copyText(btn.parentElement.querySelector("code").textContent, btn);
    else copyText(btn.getAttribute("data-copy"), btn);
  });

  function times(n) {
    var d = n % 10, h = n % 100;
    if (d === 1 && h !== 11) return n + " раз";
    if (d >= 2 && d <= 4 && (h < 12 || h > 14)) return n + " раза";
    return n + " раз";
  }
  var counters = document.querySelectorAll("[data-count]");
  if (!counters.length) return;
  var root = document.querySelector('link[rel="stylesheet"]').getAttribute("href").replace("assets/style.css", "");
  fetch(root + "stats.json", { cache: "no-store" }).then(function (r) { return r.ok ? r.json() : null; }).then(function (s) {
    if (!s) return;
    counters.forEach(function (el) {
      var n = s.downloads[el.getAttribute("data-count")] || 0;
      if (n) el.textContent = "скачали " + times(n);
    });
  }).catch(function () {});
})();
