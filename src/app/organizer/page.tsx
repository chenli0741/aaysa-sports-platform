import Link from "next/link";
import { interpolate } from "@/lib/i18n";
import { getI18n } from "@/lib/i18n-server";
import { getTournaments } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function OrganizerPage() {
  const { dictionary } = await getI18n();
  const t = dictionary.organizer;
  const tournaments = await getTournaments();
  const activeTournament = tournaments[0];

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{dictionary.home.operationsTitle}</div>
        <h1>{t.title}</h1>
        <p className="lead">{t.lead}</p>
      </section>

      <section className="grid" aria-label={t.title}>
        <article className="card">
          <h2>{t.tournaments}</h2>
          <p>{t.tournamentsBody}</p>
          <Link className="text-link" href="/organizer/tournaments">
            {t.viewTournaments}
          </Link>
        </article>
        <article className="card">
          <h2>{t.registrations}</h2>
          <p>{t.registrationsBody}</p>
          <Link
            className="text-link"
            href={activeTournament ? `/organizer/tournaments/${activeTournament.id}/registrations` : "/organizer/tournaments"}
          >
            {t.reviewRegistrations}
          </Link>
        </article>
        <article className="card">
          <h2>{t.eventDay}</h2>
          <p>{t.eventDayBody}</p>
          <div className="card-link-row">
            <Link href={activeTournament ? `/organizer/tournaments/${activeTournament.id}/schedule` : "/organizer/tournaments"}>
              {t.manageSchedule}
            </Link>
            <Link href={activeTournament ? `/organizer/tournaments/${activeTournament.id}/check-in` : "/organizer/tournaments"}>
              {t.openCheckIn}
            </Link>
            <Link href={activeTournament ? `/organizer/tournaments/${activeTournament.id}/scores` : "/organizer/tournaments"}>
              {t.scores}
            </Link>
            <Link href={activeTournament ? `/organizer/tournaments/${activeTournament.id}/standings` : "/organizer/tournaments"}>
              {t.standings}
            </Link>
          </div>
        </article>
      </section>

      <section className="list-stack">
        {tournaments.map((tournament) => (
          <article className="row-card" key={tournament.id}>
            <div>
              <span className="step-label">{t.currentEvent}</span>
              <h2>{tournament.name}</h2>
              <p>{interpolate(t.registrationCount, { count: tournament.registrations.length })}</p>
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
