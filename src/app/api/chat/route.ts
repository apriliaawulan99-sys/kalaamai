import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { getOpenAIClient, getTextModel } from "@/lib/ai/openai";
import { tutorInstructions } from "@/lib/ai/prompts";
import { allowRequest } from "@/lib/security/rate-limit";
import { jsonError, readJsonBody } from "@/lib/http";

const bodySchema = z.object({ sessionId: z.string().uuid(), message: z.string().trim().min(1).max(1500) });

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return jsonError("Silakan masuk untuk menggunakan tutor AI.", 401);

    const bodyResult = await readJsonBody(request, 10_000);
    if (!bodyResult.success) return jsonError(bodyResult.status === 413 ? "Body terlalu besar." : "Body JSON tidak valid.", bodyResult.status);
    const parsed = bodySchema.safeParse(bodyResult.data);
    if (!parsed.success) return jsonError("Pesan tidak valid. Maksimal 1.500 karakter.", 400);
    if (!(await allowRequest(user.id, "chat"))) return jsonError("Batas permintaan tercapai. Tunggu sebentar lalu coba lagi.", 429);

    const { sessionId, message } = parsed.data;
    const { data: session } = await supabase.from("conversation_sessions").select("id,scenario_id,status").eq("id", sessionId).eq("user_id", user.id).maybeSingle();
    if (!session) return jsonError("Sesi tidak ditemukan atau bukan milik akun ini.", 404);
    if (session.status !== "active") return jsonError("Sesi ini sudah ditutup. Buat sesi baru untuk melanjutkan.", 409);

    const { data: scenario } = await supabase.from("scenarios").select("title_id,title_ar,description").eq("id", session.scenario_id || "").maybeSingle();
    const { data: prior } = await supabase.from("conversation_messages").select("role,content,created_at").eq("session_id", sessionId).order("created_at", { ascending: false }).limit(12);
    const history = (prior || []).reverse().map(item => ({ role: item.role as "user" | "assistant", content: item.content }));
    history.push({ role: "user", content: message });

    let answer = "";
    try {
      const openai = getOpenAIClient();
      const response = await openai.responses.create({
        model: getTextModel(),
        instructions: tutorInstructions(scenario?.title_ar || scenario?.title_id || "Percakapan umum", scenario?.description || "Latihan percakapan bahasa Arab baku modern."),
        input: history
      });
      answer = response.output_text?.trim() || "";
    } catch (error) {
      console.error("AI chat provider request failed.");
      const missingKey = error instanceof Error && error.message.includes("OPENAI_API_KEY");
      return jsonError(missingKey ? "OPENAI_API_KEY belum dikonfigurasi di server." : "Tutor AI sedang tidak tersedia. Coba lagi sebentar.", missingKey ? 503 : 502);
    }
    if (!answer) return jsonError("Tutor AI tidak menghasilkan jawaban. Coba kirim ulang.", 502);

    const { data: userMessage, error: userMessageError } = await supabase.from("conversation_messages").insert({ session_id: sessionId, role: "user", content: message, input_type: "text" }).select("id,role,content,created_at").single();
    if (userMessageError || !userMessage) return jsonError("Pesan tidak dapat disimpan. Coba lagi.", 500);
    const { data: assistantMessage, error: assistantError } = await supabase.from("conversation_messages").insert({ session_id: sessionId, role: "assistant", content: answer, input_type: "text" }).select("id,role,content,created_at").single();
    if (assistantError || !assistantMessage) return jsonError("Respons tutor gagal disimpan. Muat ulang sesi untuk memeriksa riwayat.", 500);
    return Response.json({ userMessage, assistantMessage });
  } catch (error) {
    console.error("Chat route failed.");
    return jsonError(error instanceof Error && error.message.includes("Supabase belum") ? error.message : "Layanan percakapan belum dikonfigurasi atau sedang bermasalah.", 503);
  }
}
