import Link from "next/link";
import { RegisterForm } from "@/components/auth-forms";
import { getI18n } from "@/lib/i18n-server";

export default async function SignUpPage() {
  const { locale } = await getI18n();
  const copy =
    locale === "zh"
      ? {
          eyebrow: "账户",
          title: "创建账户",
          lead: "创建账户后，系统会用邮箱把你和已有报名记录关联起来。",
          signIn: "已有账户？登录"
        }
      : {
          eyebrow: "Account",
          title: "Create account",
          lead: "Create an account and existing registrations with the same email will be linked automatically.",
          signIn: "Already have an account? Sign in"
        };

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{copy.eyebrow}</div>
        <h1>{copy.title}</h1>
        <p className="lead">{copy.lead}</p>
      </section>

      <section className="form-section auth-section">
        <RegisterForm locale={locale} />
        <Link className="text-link" href="/auth/sign-in">
          {copy.signIn}
        </Link>
      </section>
    </main>
  );
}
