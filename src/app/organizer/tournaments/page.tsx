import Link from "next/link";
import { formatDateRange } from "@/lib/format";
import { labelStatus } from "@/lib/i18n";
import { getI18n } from "@/lib/i18n-server";
import { getTournaments } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function OrganizerTournamentsPage() {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.organizer;
  const tournaments = await getTournaments();

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{t.title}</div>
        <h1>{t.tournaments}</h1>
        <p className="lead">{t.tournamentLead}</p>
      </section>

      <section className="list-stack">
        {tournaments.map((tournament) => (
          <article className="row-card" key={tournament.id}>
            <div>
              <span className="status-pill">{labelStatus(tournament.status, locale)}</span>
              <h2>{tournament.name}</h2>
              <p>{formatDateRange(tournament.startsAt, tournament.endsAt, locale)}</p>
            </div>
            <Link className="button secondary" href={`/organizer/tournaments/${tournament.id}`}>
              {dictionary.common.manage}
            </Link>
          </article>
        ))}
      </section>
    </main>
  );
}
