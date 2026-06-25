(function () {
  "use strict";

  // build the 60-cell temperature bar — gradient distribution, warn/crit zones
  function buildBars() {
    var host = document.getElementById("bars");
    var frag = document.createDocumentFragment();
    for (var i = 0; i < 60; i++) {
      var cell = document.createElement("span");
      frag.appendChild(cell);
    }
    host.appendChild(frag);
  }

  // animate fill level of the bar, leftmost cells = red, then amber, then green
  function paintBars(level) {
    var cells = document.querySelectorAll("#bars span");
    for (var i = 0; i < cells.length; i++) {
      var c = cells[i];
      c.classList.remove("on", "warn", "crit");
      if (i >= cells.length - level) {
        if (i < 6) c.classList.add("crit");
        else if (i < 14) c.classList.add("warn");
        else c.classList.add("on");
      }
    }
  }

  // pad number with leading zeros
  function pad(n, w) {
    var s = String(n);
    while (s.length < w) s = "0" + s;
    return s;
  }

  // tick wall-clock + date once per second
  function tickClock() {
    var d = new Date();
    document.getElementById("clock").textContent =
      pad(d.getHours(), 2) + ":" + pad(d.getMinutes(), 2) + ":" + pad(d.getSeconds(), 2);
    document.getElementById("date").textContent =
      pad(d.getDate(), 2) + "." + pad(d.getMonth() + 1, 2) + "." + d.getFullYear();
  }

  // gently drift a numeric readout around a base value
  function drift(id, base, jitter, decimals) {
    var el = document.getElementById(id);
    var v = base + (Math.random() - 0.5) * jitter;
    el.textContent = decimals ? v.toFixed(decimals) : String(Math.round(v));
  }

  // refresh all sensor readouts
  var barLevel = 42;
  function tickReadouts() {
    drift("v-temp", 284, 4, 0);
    drift("v-pwr",   46, 1, 0);
    drift("v-react", 30, 0.4, 1);
    drift("v-flow",  74, 2, 0);
    drift("v-flux", 2410, 30, 0);
    drift("v-bor",  0.8, 0.05, 2);
    drift("v-p1",  1268, 6, 0);
    drift("v-p2",   87, 1, 0);
    drift("v-lvl",  96, 1, 0);
    drift("v-sig",  2.2, 0.15, 1);

    barLevel += (Math.random() - 0.5) * 3;
    if (barLevel < 30) barLevel = 30;
    if (barLevel > 56) barLevel = 56;
    paintBars(Math.round(barLevel));
  }

  // append a new event line to the log, trim to last N
  // each entry carries a severity class — drives color (amber default, green ok, red crit)
  var LOG_MAX = 8;
  var LOG_EVENTS = [
    { cls: "",     msg: "ПОДАЧА ТН-2 СТАБИЛЬНА" },
    { cls: "",     msg: "РЕГ. СТЕРЖЕНЬ №07 — ПОДЪЁМ 14 СМ" },
    { cls: "ok",   msg: "ТЕМП. АЗ В ПРЕДЕЛАХ НОРМЫ" },
    { cls: "ok",   msg: "СИГНАЛ ОТ Д-9: КОНТРОЛЬ ОК" },
    { cls: "",     msg: "ПЕРИОД РАЗГОНА: > 200 С" },
    { cls: "ok",   msg: "ПГ-1 УРОВЕНЬ В ДОПУСКЕ" },
    { cls: "",     msg: "ОТКЛОНЕНИЕ ПО НЕЙТР. ПОТОКУ: 0.4%" },
    { cls: "",     msg: "ИНЪЕКЦИЯ БОРА: ПЛАН. РЕЖИМ" },
    { cls: "ok",   msg: "КОНТУР-2: ДАВЛЕНИЕ СТАБИЛЬНО" },
    { cls: "ok",   msg: "ПОВЕРКА КИП ОТ Д-3 ВЫПОЛНЕНА" },
    { cls: "",     msg: "ТУРБИНА: ВЫХОД НА ХОЛОСТОЙ ХОД" },
    { cls: "crit", msg: "ВНИМАНИЕ: ДРОБЬ ТЕМП. АЗ +6°С" },
    { cls: "crit", msg: "АВАРИЯ: СБОЙ ДАТЧИКА Н-3" },
    { cls: "crit", msg: "ПОТЕРЯ СИГНАЛА ОТ КИП-12" },
    { cls: "crit", msg: "ПРЕДУПР: УРОВЕНЬ ПГ-2 — ГРАНИЦА" },
    { cls: "ok",   msg: "ПЕРЕХОД В РЕЖИМ N-1: ОК" }
  ];
  function pushLog() {
    var ul = document.getElementById("log");
    var d = new Date();
    var stamp = pad(d.getHours(), 2) + ":" + pad(d.getMinutes(), 2) + ":" + pad(d.getSeconds(), 2);
    var ev = LOG_EVENTS[Math.floor(Math.random() * LOG_EVENTS.length)];
    var li = document.createElement("li");
    if (ev.cls) li.className = ev.cls;
    li.textContent = stamp + " · " + ev.msg;
    ul.appendChild(li);
    while (ul.children.length > LOG_MAX) ul.removeChild(ul.firstChild);
  }

  // button click — push a custom log line per action
  function wireButtons() {
    var btns = document.querySelectorAll(".btn:not(.locked)");
    var actions = ["СТАРТ ВЫПОЛНЕН", "ПРОВЕРКА ИНИЦИИРОВАНА", "ТУРБИНА ВВЕДЕНА В РЕЖИМ"];
    btns.forEach(function (b, i) {
      b.addEventListener("click", function () {
        var ul = document.getElementById("log");
        var d = new Date();
        var stamp = pad(d.getHours(), 2) + ":" + pad(d.getMinutes(), 2) + ":" + pad(d.getSeconds(), 2);
        var li = document.createElement("li");
        li.textContent = stamp + " · " + actions[i];
        ul.appendChild(li);
        while (ul.children.length > LOG_MAX) ul.removeChild(ul.firstChild);
      });
    });
  }

  // boot
  buildBars();
  paintBars(barLevel);
  tickClock();
  tickReadouts();
  wireButtons();
  // clock + readouts + log driven by player actions in real use, not interval ticks
  // setInterval(tickClock, 1000);
  // setInterval(tickReadouts, 3000);
  // setInterval(pushLog, 6000);
})();
