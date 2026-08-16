import { getI18n } from "@/lib/i18n-server";

export default async function RulesPage() {
  const { dictionary } = await getI18n();
  const t = dictionary.rules;

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{dictionary.common.public}</div>
        <h1>{t.title}</h1>
        <p className="lead">{t.lead}</p>
      </section>

      <section className="grid">
        <article className="card">
          <h2>{t.rosterTitle}</h2>
          <p>{t.rosterBody}</p>
        </article>
        <article className="card">
          <h2>{t.waiversTitle}</h2>
          <p>{t.waiversBody}</p>
        </article>
        <article className="card">
          <h2>{t.standingsTitle}</h2>
          <p>{t.standingsBody}</p>
        </article>
      </section>
    </main>
  );
}
