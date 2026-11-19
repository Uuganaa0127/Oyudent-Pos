const bytesOf = (key) =>
  Uint8Array.from(atob(embedded[key]), (c) => c.charCodeAt(0));
const moduleUrl = (key) =>
  URL.createObjectURL(new Blob([bytesOf(key)], { type: "text/javascript" }));
let pdfLibrary;
async function openOCR() {
  // Feed traineddata from this HTML file into the worker's normal language loader.
  const prefix = `const langs = ${JSON.stringify({ eng: embedded.eng, mon: embedded.mon })};
 const originalFetch=self.fetch.bind(self);
 self.fetch=(input,options)=>{
   const code=Object.keys(langs).find(k=>String(input)==='https://offline.invalid/languages/'+k+'.traineddata.gz');
   return code?Promise.resolve(new Response(Uint8Array.from(atob(langs[code]),c=>c.charCodeAt(0)))):originalFetch(input,options);
 };\n`;
  const url = URL.createObjectURL(
      new Blob([prefix, bytesOf("ocrWorker")], { type: "text/javascript" }),
    ),
    core = moduleUrl("ocrCore");
  let worker;
  try {
    worker = await Tesseract.createWorker("eng+mon", 1, {
      workerPath: url,
      workerBlobURL: false,
      corePath: core + "#core.js",
      langPath: "https://offline.invalid/languages",
      cacheMethod: "none",
      logger: (m) => {
        $("status").textContent =
          "Текст таньж байна… " + Math.round(100 * m.progress) + "%";
      },
    });
    return worker;
  } finally {
    URL.revokeObjectURL(url);
    URL.revokeObjectURL(core);
  }
}
async function withOCR(callback) {
  const worker = await openOCR();
  try {
    return await callback(worker);
  } finally {
    await worker.terminate();
  }
}
async function readPdf(bytes) {
  if (!pdfLibrary) {
    const lib = moduleUrl("pdf"),
      worker = moduleUrl("pdfWorker");
    try {
      globalThis.pdfjsWorker = await import(worker);
      pdfLibrary = await import(lib);
    } finally {
      URL.revokeObjectURL(lib);
      URL.revokeObjectURL(worker);
    }
  }
  const pdf = await pdfLibrary.getDocument({
    data: bytes,
    isEvalSupported: false,
    useWorkerFetch: false,
  }).promise;
  const pages = [];
  let worker;
  try {
    for (let i = 1; i <= pdf.numPages; i++) {
      $("status").textContent = "PDF · " + i + " / " + pdf.numPages;
      const page = await pdf.getPage(i),
        content = await page.getTextContent();
      const items = content.items.filter((v) => v.str?.trim());
      if (items.map((v) => v.str).join("").length > 15) {
        const lines = [];
        for (const v of items) {
          const y = v.transform[5];
          let row = lines.find((r) => Math.abs(r.y - y) < 2);
          if (!row) {
            row = { y, cells: [] };
            lines.push(row);
          }
          row.cells.push(v);
        }
        pages.push(
          lines
            .sort((a, b) => b.y - a.y)
            .map((r) =>
              r.cells
                .sort((a, b) => a.transform[4] - b.transform[4])
                .map((v) => v.str)
                .join("\t"),
            )
            .join("\n"),
        );
      } else {
        const original = page.getViewport({ scale: 1 });
        const viewport = page.getViewport({
          scale: Math.min(
            2.5,
            2600 / Math.max(original.width, original.height),
          ),
        });
        const canvas = document.createElement("canvas");
        canvas.width = Math.ceil(viewport.width);
        canvas.height = Math.ceil(viewport.height);
        await page.render({ canvasContext: canvas.getContext("2d"), viewport })
          .promise;
        worker ??= await openOCR();
        pages.push((await worker.recognize(canvas)).data.text);
        canvas.width = canvas.height = 0;
      }
      page.cleanup();
    }
  } finally {
    if (worker) await worker.terminate();
    await pdf.destroy();
  }
  return pages.join("\n");
}
