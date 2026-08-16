import { formatDateTime } from "@/lib/format";
import { getI18n } from "@/lib/i18n-server";
import { getTournaments } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function AppTodayPage() {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.accountPages;
  const tournaments = await getTournaments();

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{dictionary.common.mobileApp}</div>
        <h1>{t.todayTitle}</h1>
        <p className="lead">{t.todayLead}</p>
      </section>

      <section className="list-stack">
        {tournaments.flatMap((tournament) =>
          tournament.sessions.map((session) => (
            <article className="row-card" key={session.id}>
              <div>
                <span className="step-label">{tournament.name}</span>
                <h2>{session.name}</h2>
                <p>{formatDateTime(session.startsAt, locale)}</p>
              </div>
            </article>
          ))
        )}
      </section>
    </main>
  );
}
