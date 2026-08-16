import Link from "next/link";
import { getI18n } from "@/lib/i18n-server";

export default async function NotFound() {
  const { dictionary } = await getI18n();
  const t = dictionary.notFound;

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">404</div>
        <h1>{t.title}</h1>
        <p className="lead">{t.lead}</p>
        <div className="actions">
          <Link className="button" href="/">
            {t.action}
          </Link>
        </div>
      </section>
    </main>
  );
}
