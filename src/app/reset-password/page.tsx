import type { Metadata } from "next";
import { ResetPasswordForm } from "@/components/reset-password-form";
export const metadata: Metadata = { title: "Buat kata sandi baru" };
export default function ResetPasswordPage(){return <main className="flex min-h-screen items-center justify-center px-5 py-10"><ResetPasswordForm/></main>}
