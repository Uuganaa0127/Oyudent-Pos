// Run npm ci, then node build.cjs to rebuild the offline desktop asset.
const fs = require("node:fs"),
  path = require("node:path");
function dep(name, relative) {
  return fs.readFileSync(
    path.join(
      path.join(
        require.resolve
          .paths(name)
          .find((d) => fs.existsSync(path.join(d, name, "package.json"))),
        name,
      ),
      relative,
    ),
  );
}
const read = (name) => fs.readFileSync(path.join(__dirname, name), "utf8");
const embedded = {};
for (const [key, name, file] of [
  ["pdf", "pdfjs-dist", "build/pdf.min.mjs"],
  ["pdfWorker", "pdfjs-dist", "build/pdf.worker.min.mjs"],
  ["ocrWorker", "tesseract.js", "dist/worker.min.js"],
  ["ocrCore", "tesseract.js-core", "tesseract-core-lstm.wasm.js"],
  ...["eng", "mon"].map((l) => [
    l,
    "@tesseract.js-data/" + l,
    "4.0.0_best_int/" + l + ".traineddata.gz",
  ]),
])
  embedded[key] = dep(name, file).toString("base64");
function script(source) {
  return (
    "<script>" +
    String(source).replace(/<\/script/gi, "<\\/script") +
    "\n</script>"
  );
}
const licenses = [
  ["xlsx", "LICENSE"],
  ["pdfjs-dist", "LICENSE"],
  ["tesseract.js", "LICENSE.md"],
  ["tesseract.js", "dist/tesseract.min.js.LICENSE.txt"],
  ["tesseract.js", "dist/worker.min.js.LICENSE.txt"],
  ["tesseract.js-core", "LICENSE"],
]
  .map(([n, p]) => n + "\n" + dep(n, p))
  .join("\n");
const output = path.join(__dirname, "../../assets/oyudent-excel.html");
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(
  output,
  read("page.html") +
    script(dep("xlsx", "dist/xlsx.full.min.js")) +
    script(dep("tesseract.js", "dist/tesseract.min.js")) +
    script("const embedded=" + JSON.stringify(embedded)) +
    script(read("documents.js")) +
    script(read("converter.js")) +
    '<template id="licenses">' +
    licenses.replace(/&/g, "&amp;").replace(/</g, "&lt;") +
    "</template>",
);
