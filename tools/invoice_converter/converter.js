// Excel import headers are kept independent of the Mongolian screen labels.
const pi = [
  "name",
  "reference",
  "manufacturer",
  "specification",
  "quantity",
  "unit_cost",
  "barcode",
  "lot",
  "expiry",
  "purchase_unit",
  "pieces_per_unit",
  "price_basis",
];
const products = [
  "Code",
  "Name",
  "MnName",
  "Description",
  "CategoryCode",
  "Brand",
  "IsShowLanding",
  "IsPopular",
  "OnSale",
  "MainImage",
];
const variants = [
  "ProductCode",
  "Color",
  "Size",
  "Barcode",
  "Images",
  "UnitCode",
  "Weight",
  "FirstBalance",
];
const aliases = {
  name: [
    "Барааны нэр",
    "Product name",
    "Name",
    "Item name",
    "Product",
    "Description",
  ],
  reference: [
    "Лавлах дугаар",
    "Reference",
    "REF",
    "SKU",
    "Product code",
    "Code",
    "Catalog no",
  ],
  manufacturer: ["Үйлдвэрлэгч", "Manufacturer", "Brand"],
  specification: ["Үзүүлэлт", "Specification", "Model"],
  quantity: ["Тоо хэмжээ", "Quantity", "Qty", "Qty/Pcs", "QTY (PCS)"],
  unit_cost: ["Нэгж үнэ", "Unit price", "Unit cost", "Price"],
  barcode: ["Баркод", "Barcode", "EAN"],
  lot: ["Лот дугаар", "Lot", "Batch", "Lot No"],
  expiry: ["Дуусах огноо", "Expiry", "Expiration date"],
  purchase_unit: ["Худалдан авах нэгж", "Unit", "UOM"],
  pieces_per_unit: ["Нэгж дэх ширхэг", "Pieces per unit"],
  price_basis: ["Үнийн суурь", "Price basis"],
  MnName: ["Монгол нэр", "Mongolian name"],
  Description: ["Тайлбар", "Description"],
  CategoryCode: ["Ангилал", "Category", "CategoryCode"],
  IsShowLanding: ["Нүүр хуудсанд харуулах"],
  IsPopular: ["Эрэлттэй"],
  OnSale: ["Хямдралтай"],
  MainImage: ["Үндсэн зургийн файл"],
  Color: ["Өнгө", "Shade"],
  Size: ["Хэмжээ", "Size"],
  Images: ["Хувилбарын зураг"],
  Weight: ["Жин", "Weight"],
  FirstBalance: ["Эхний үлдэгдэл", "Opening balance"],
};
Object.assign(aliases, {
  Code: aliases.reference,
  Name: aliases.name,
  Brand: aliases.manufacturer,
  Barcode: aliases.barcode,
  UnitCode: aliases.purchase_unit,
});
const $ = (id) => document.getElementById(id);
const norm = (s) =>
  String(s ?? "")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]/gu, "");
const esc = (s) => String(s ?? "").trim();
const activeFields = () =>
  $("mode").value === "pi" ? pi : [...products, ...variants.slice(1)];
const node = (tag, text) => {
  const n = document.createElement(tag);
  if (text !== undefined) n.textContent = text;
  return n;
};
let sheets = {},
  rows = [],
  dirty = false,
  pageIndex = 0;
function selectIndex(key, head) {
  for (const hint of [key, ...(aliases[key] || [])]) {
    const i = head.findIndex((v) => norm(v) === norm(hint));
    if (i >= 0) return i;
  }
  return -1;
}
function source() {
  return sheets[$("sheet").value] || [];
}
function detectHead() {
  let best = 0,
    max = 0;
  source().forEach((r, i) => {
    const score = activeFields().filter((k) => selectIndex(k, r) >= 0).length;
    if (score > max) {
      best = i;
      max = score;
    }
  });
  $("head").value = best + 1;
}
function mapColumns() {
  const data = source(),
    index = Number($("head").value) - 1;
  if (
    data.length &&
    (!Number.isInteger(index) || index < 0 || index >= data.length)
  )
    throw Error("Гарчгийн мөрийн дугаарыг шалгана уу.");
  const head = data[index] || [];
  const width = data.reduce((n, r) => Math.max(n, r.length), head.length);
  const box = $("mapping");
  box.replaceChildren();
  for (const key of activeFields()) {
    const label = node("label", aliases[key][0]),
      s = node("select");
    s.dataset.key = key;
    s.add(new Option("—", "-1"));
    for (let i = 0; i < width; i++)
      s.add(new Option(i + 1 + ". " + (head[i] || "—"), String(i)));
    s.value = String(selectIndex(key, head));
    label.append(s);
    box.append(label);
  }
}
function materialize() {
  const map = Array.from($("mapping").querySelectorAll("select"), (s) => [
    s.dataset.key,
    Number(s.value),
  ]);
  if (source().length && map.every(([, col]) => col < 0))
    throw Error("Дор хаяж нэг эх багана сонгоно уу.");
  rows = source()
    .slice(Number($("head").value))
    .map((r) => Object.fromEntries(map.map(([k, c]) => [k, esc(r[c])])))
    .filter((r) => Object.values(r).some(Boolean))
    .map((r) => ({ ...r, selected: true }));
  pageIndex = 0;
  dirty = false;
  $("download").disabled = false;
  draw();
}
function draw() {
  const fields = activeFields(),
    h = node("tr");
  h.append(node("th", "Сонгох"));
  for (const k of fields) h.append(node("th", aliases[k][0]));
  $("headers").replaceChildren(h);
  const body = $("rows");
  body.replaceChildren();
  pageIndex = Math.min(pageIndex, Math.max(0, Math.ceil(rows.length / 40) - 1));
  const start = pageIndex * 40,
    end = Math.min(start + 40, rows.length);
  $("range").textContent = rows.length
    ? start + 1 + "–" + end + " / " + rows.length + " мөр"
    : "";
  $("prev").hidden = start === 0;
  $("next").hidden = end === rows.length;
  rows.slice(start, end).forEach((r) => {
    const tr = node("tr"),
      td = node("td"),
      check = node("input");
    check.type = "checkbox";
    check.checked = r.selected;
    check.onchange = () => {
      r.selected = check.checked;
      dirty = true;
    };
    td.append(check);
    tr.append(td);
    fields.forEach((k) => {
      const td = node("td"),
        input = node("input");
      input.value = r[k] || "";
      input.setAttribute("aria-label", aliases[k][0]);
      if (k === "expiry") input.placeholder = "YYYY-MM-DD";
      if (k === "price_basis") input.placeholder = "piece / purchase_unit";
      input.oninput = () => {
        r[k] = input.value.trim();
        dirty = true;
      };
      td.append(input);
      tr.append(td);
    });
    body.append(tr);
  });
  $("meta").hidden = $("mode").value !== "pi";
  $("error").textContent = "";
}
function mappingChanged() {
  $("download").disabled = true;
  $("error").textContent =
    "Баганын тохиргоо өөрчлөгдлөө. Эх файлаас мөрүүдийг дахин авна уу.";
}
function makeBook() {
  const book = XLSX.utils.book_new(),
    selected = rows.map((r, i) => [r, i + 1]).filter(([r]) => r.selected);
  if (!selected.length) throw Error("Хадгалах мөр сонгоно уу.");
  const add = (name, headers, list) =>
    XLSX.utils.book_append_sheet(
      book,
      XLSX.utils.aoa_to_sheet([
        headers,
        ...list.map((r) => headers.map((k) => r[k] ?? "")),
      ]),
      name,
    );
  if ($("mode").value === "pi") {
    const currency = $("currency").value.trim().toUpperCase();
    if (!/^[A-Z]{3}$/.test(currency))
      throw Error("Валютыг гурван үсгээр оруулна уу (жишээ нь USD).");
    const records = selected.map(([r, i]) => {
      const fail = (text) => {
        throw Error(i + "-р мөр: " + text);
      };
      if (!r.name) fail("Барааны нэр оруулна уу.");
      const out = { ...r };
      for (const k of ["quantity", "unit_cost", "pieces_per_unit"]) {
        if (k === "pieces_per_unit" && !out[k]) continue;
        if (
          !/^\d+(\.\d+)?$/.test(out[k]) ||
          !Number.isFinite(+out[k]) ||
          (k !== "unit_cost" && +out[k] <= 0) ||
          (k === "pieces_per_unit" && !Number.isInteger(+out[k]))
        )
          fail(aliases[k][0] + " · зөв тоо оруулна уу.");
        out[k] = Number(out[k]);
      }
      if (
        out.price_basis &&
        !["piece", "purchase_unit"].includes(out.price_basis)
      )
        fail("Үнийн суурь нь piece эсвэл purchase_unit байна.");
      if (
        out.expiry &&
        (!/^\d{4}-\d\d-\d\d$/.test(out.expiry) ||
          !Number.isFinite(Date.parse(out.expiry)) ||
          new Date(out.expiry).toISOString().slice(0, 10) !== out.expiry)
      )
        fail("Дуусах огноог YYYY-MM-DD хэлбэрээр оруулна уу.");
      return out;
    });
    add(
      "Invoice",
      ["currency", "invoice_number", "invoice_date", "supplier"],
      [
        {
          currency,
          invoice_number: $("invoice").value,
          invoice_date: $("date").value,
          supplier: $("supplier").value,
        },
      ],
    );
    add("Items", pi, records);
  } else {
    const byCode = new Map(),
      v = [],
      barcodes = new Set();
    for (const [r, i] of selected) {
      if (!r.Code || !r.Name || !r.CategoryCode || !r.Brand)
        throw Error(
          i + "-р мөр: лавлах дугаар, нэр, ангилал, үйлдвэрлэгчээ бөглөнө үү.",
        );
      const product = Object.fromEntries(products.map((k) => [k, r[k] || ""]));
      for (const k of ["IsShowLanding", "IsPopular", "OnSale"]) {
        const flag = String(product[k]).toLowerCase();
        if (!["", "0", "1", "true", "false"].includes(flag))
          throw Error(i + "-р мөр: " + aliases[k][0] + " нь 0 эсвэл 1 байна.");
        if (flag) product[k] = flag === "1" || flag === "true";
      }
      if (
        byCode.has(r.Code) &&
        JSON.stringify(byCode.get(r.Code)) !== JSON.stringify(product)
      )
        throw Error(i + "-р мөр: ижил кодтой барааны мэдээлэл зөрж байна.");
      byCode.set(r.Code, product);
      if (variants.slice(1).some((k) => r[k])) {
        if (!r.Barcode || barcodes.has(r.Barcode))
          throw Error(i + "-р мөр: хувилбар бүр давхцаагүй баркодтой байна.");
        if (r.FirstBalance && !/^\d+(\.\d+)?$/.test(r.FirstBalance))
          throw Error(i + "-р мөр: эхний үлдэгдлийг шалгана уу.");
        barcodes.add(r.Barcode);
        v.push({
          ...r,
          ProductCode: r.Code,
          FirstBalance: r.FirstBalance ? Number(r.FirstBalance) : "",
        });
      }
    }
    add("Products", products, [...byCode.values()]);
    add("Variants", variants, v);
  }
  return book;
}
function warnReplace() {
  return !dirty || confirm("Зассан мөрүүдийг эх файлаас дахин авах уу?");
}
function guard(fn) {
  return async () => {
    try {
      $("error").textContent = "";
      await fn();
    } catch (e) {
      $("error").textContent = e.message || String(e);
      $("error").scrollIntoView({ block: "nearest" });
    }
  };
}
function setSheets(book) {
  $("download").disabled = false;
  sheets = book;
  $("sheet").replaceChildren();
  for (const key of Object.keys(book)) $("sheet").add(new Option(key, key));
  if (!Object.keys(book).length) throw Error("Хүснэгт олдсонгүй.");
  if (book.Items) $("sheet").value = "Items";
  detectHead();
  mapColumns();
  if (
    Array.from($("mapping").querySelectorAll("select")).some(
      (s) => s.value !== "-1",
    )
  )
    materialize();
  else {
    rows = [];
    dirty = false;
    draw();
  }
}
function textTable(s) {
  if (!s.trim()) throw Error("Текст хоосон байна.");
  if (s.includes("\t") || /[,;]/.test(s.split(/\r?\n/)[0])) {
    const book = XLSX.read(s, {
      type: "string",
      raw: true,
      ...(s.includes("\t") ? { FS: "\t" } : {}),
    });
    return table(book.Sheets[book.SheetNames[0]]);
  }
  return s
    .trim()
    .split(/\r?\n/)
    .map((line) => line.trim().split(/ {2,}/));
}
function table(sheet) {
  return XLSX.utils.sheet_to_json(sheet, {
    header: 1,
    raw: false,
    defval: "",
    blankrows: true,
  });
}
$("file").onchange = guard(async () => {
  const f = $("file").files[0];
  if (!f) return;
  if (!warnReplace()) {
    $("file").value = "";
    return;
  }
  const section = document.querySelector("main");
  section.inert = true;
  $("status").textContent = "Файлыг уншиж байна…";
  try {
    const ext = f.name.split(".").pop().toLowerCase(),
      bytes = new Uint8Array(await f.arrayBuffer());
    let book,
      text = "";
    if (["csv", "tsv"].includes(ext)) {
      const content = new TextDecoder(
        bytes[0] === 255 && bytes[1] === 254 ? "utf-16le" : "utf-8",
      ).decode(bytes);
      book = { Хүснэгт: textTable(content) };
    } else if (["xlsx", "xls", "xlsm", "ods"].includes(ext)) {
      const w = XLSX.read(bytes, {
        type: "array",
        raw: true,
        cellDates: true,
        dateNF: "yyyy-mm-dd",
      });
      book = Object.fromEntries(
        w.SheetNames.map((n) => [n, table(w.Sheets[n])]),
      );
    } else if (ext === "txt") {
      text = new TextDecoder().decode(bytes);
    } else if (ext === "docx") {
      const zip = XLSX.CFB.read(bytes, { type: "array" }),
        entry =
          zip.FileIndex[
            zip.FullPaths.findIndex((p) => p.endsWith("/word/document.xml"))
          ];
      if (!entry) throw Error("Word файл уншигдсангүй.");
      const doc = new DOMParser().parseFromString(
        new TextDecoder().decode(entry.content),
        "application/xml",
      );
      const tables = Array.from(doc.getElementsByTagNameNS("*", "tbl"));
      if (tables.length)
        book = Object.fromEntries(
          tables.map((t, i) => [
            "Хүснэгт " + (i + 1),
            Array.from(t.getElementsByTagNameNS("*", "tr"), (r) =>
              Array.from(r.children)
                .filter((e) => e.localName === "tc")
                .map((cell) => cell.textContent.trim()),
            ),
          ]),
        );
      else
        text = Array.from(
          doc.getElementsByTagNameNS("*", "p"),
          (n) => n.textContent,
        ).join("\n");
    } else if (ext === "pdf") {
      text = await readPdf(bytes);
    } else if (["jpg", "jpeg", "png", "webp"].includes(ext)) {
      text = await withOCR((worker) =>
        worker.recognize(f).then((result) => result.data.text),
      );
    } else
      throw Error("Дэмжигдээгүй файл. Хүснэгт эсвэл текстээ хуулж оруулна уу.");
    $("paste").value = text;
    $("textBox").open = !!text;
    if (!book) book = { "Танигдсан текст": textTable(text) };
    if (book.Products && book.Variants) {
      const [ph, ...pr] = book.Products,
        [vh, ...vr] = book.Variants;
      if (!ph || !vh || !ph.includes("Code") || !vh.includes("ProductCode"))
        throw Error("Products, Variants хуудасны багануудыг шалгана уу.");
      const pk = ph.indexOf("Code"),
        fk = vh.indexOf("ProductCode"),
        codes = new Set(pr.map((r) => r[pk]));
      const groups = new Map();
      for (const r of vr.filter((r) => r.some((v) => esc(v)))) {
        if (!codes.has(r[fk]))
          throw Error(
            "Variants хуудсанд бүртгэлгүй барааны код байна: " + r[fk],
          );
        if (!groups.has(r[fk])) groups.set(r[fk], []);
        groups.get(r[fk]).push(r);
      }
      const names = vh.filter((_, i) => i !== fk);
      book = {
        "Бараа ба хувилбар": [
          [...ph, ...names],
          ...pr.flatMap((r) => {
            const linked = groups.get(r[pk]) || [[]];
            return linked.map((v) => [
              ...ph.map((_, i) => r[i] ?? ""),
              ...names.map((k) => v[vh.indexOf(k)] ?? ""),
            ]);
          }),
        ],
      };
      $("mode").value = lastMode = "product";
    } else if (book.Invoice && book.Items) {
      $("mode").value = lastMode = "pi";
    }
    for (const id of ["invoice", "supplier", "currency", "date"])
      $(id).value = "";
    setSheets(book);
    if (book.Invoice && book.Items) {
      const [h, r] = book.Invoice;
      if (h && r) {
        for (const [i, k] of Object.entries({
          invoice: "invoice_number",
          supplier: "supplier",
          currency: "currency",
          date: "invoice_date",
        }))
          $(i).value = r[h.indexOf(k)] || "";
      }
    }
    $("status").textContent = f.name + " · Багана болон мөр бүрийг шалгана уу.";
  } catch (e) {
    $("status").textContent = "Файлыг хөрвүүлж чадсангүй.";
    throw e;
  } finally {
    section.inert = false;
  }
});
$("sheet").onchange = guard(() => {
  mappingChanged();
  detectHead();
  mapColumns();
});
$("mapBtn").onclick = guard(() => {
  mappingChanged();
  mapColumns();
});
$("apply").onclick = guard(() => {
  if (warnReplace()) {
    mapColumnsIfStale();
    materialize();
  }
});
function mapColumnsIfStale() {
  if (!$("mapping").children.length) mapColumns();
}
$("prev").onclick = () => {
  pageIndex--;
  draw();
};
$("next").onclick = () => {
  pageIndex++;
  draw();
};
$("head").onchange = guard(() => {
  mappingChanged();
  mapColumns();
});
$("mapping").onchange = mappingChanged;
let lastMode = $("mode").value;
$("mode").onchange = guard(() => {
  if (!warnReplace()) {
    $("mode").value = lastMode;
    return;
  }
  $("download").disabled = false;
  lastMode = $("mode").value;
  detectHead();
  mapColumns();
  if (
    source().length &&
    Array.from($("mapping").querySelectorAll("select")).some(
      (s) => s.value !== "-1",
    )
  )
    materialize();
  else {
    rows = [];
    draw();
  }
});
$("useText").onclick = guard(() => {
  if (warnReplace()) {
    const grid = textTable($("paste").value);
    setSheets({ Хүснэгт: grid });
    $("status").textContent = "Оруулсан текстээс хүснэгт үүсгэлээ.";
  }
});
$("add").onclick = () => {
  rows.push({ selected: true });
  pageIndex = Math.floor((rows.length - 1) / 40);
  dirty = true;
  draw();
};
$("download").onclick = guard(() => {
  const w = makeBook();
  XLSX.writeFile(
    w,
    $("mode").value === "pi" ? "invoice.oyupi.xlsx" : "oyudent-products.xlsx",
    { bookSST: false },
  );
  $("error").textContent =
    $("mode").value === "pi"
      ? "Орлого → PI импортлох хэсэгт хадгалсан файлаа сонгоно уу."
      : "Бараа → Бараа импортлох хэсэгт файлаа сонгож урьдчилан шалгана уу.";
});
draw();
