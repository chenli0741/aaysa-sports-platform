import Link from "next/link";
import { SignInForm } from "@/components/auth-forms";
import { getI18n } from "@/lib/i18n-server";

export default async function SignInPage() {
  const { locale } = await getI18n();
  const copy =
    locale === "zh"
      ? {
          eyebrow: "账户",
          title: "登录",
          lead: "使用邮箱和密码登录后，可以查看自己的队伍、球员、比赛和免责声明。",
          create: "还没有账户？创建账户"
        }
      : {
          eyebrow: "Account",
          title: "Sign in",
          lead: "Sign in with email and password to view your teams, athletes, games, and waivers.",
          create: "Need an account? Create one"
        };

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{copy.eyebrow}</div>
        <h1>{copy.title}</h1>
        <p className="lead">{copy.lead}</p>
      </section>

      <section className="form-section auth-section">
        <SignInForm locale={locale} />
        <Link className="text-link" href="/auth/sign-up">
          {copy.create}
        </Link>
      </section>
    </main>
  );
}
