import { getI18n } from "@/lib/i18n-server";

export default async function WaiversPage() {
  const { dictionary } = await getI18n();
  const t = dictionary.accountPages;

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{dictionary.common.account}</div>
        <h1>{t.waiversTitle}</h1>
        <p className="lead">{t.waiversLead}</p>
      </section>
    </main>
  );
}
