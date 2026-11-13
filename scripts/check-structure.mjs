// Fails fast with a clear message if the project was pushed/uploaded incompletely.
import { existsSync } from "node:fs";
const required = ["src/app/layout.tsx", "src/app/page.tsx", "src/lib/supabase/server.ts", "middleware.ts"];
const missing = required.filter((p) => !existsSync(p));
if (missing.length) {
  console.error("\nKalamAI: file proyek tidak lengkap. Hilang:\n - " + missing.join("\n - "));
  console.error("\nPastikan folder src/ ikut ter-push ke GitHub (gunakan git push, bukan upload manual).\n");
  process.exit(1);
}
console.log("KalamAI: struktur proyek OK.");
