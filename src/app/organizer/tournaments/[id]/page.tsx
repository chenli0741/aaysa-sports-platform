import Link from "next/link";
import { notFound } from "next/navigation";
import { formatDateRange } from "@/lib/format";
import { interpolate } from "@/lib/i18n";
import { getI18n } from "@/lib/i18n-server";
import { getOrganizerTournament } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function OrganizerTournamentPage({
  params
}: {
  params: Promise<{ id: string }>;
}) {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.organizer;
  const { id } = await params;
  const tournament = await getOrganizerTournament(id);

  if (!tournament) {
    notFound();
  }

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{t.title}</div>
        <h1>{tournament.name}</h1>
        <p className="lead">{formatDateRange(tournament.startsAt, tournament.endsAt, locale)}</p>
      </section>

      <section className="grid">
        <article className="card">
          <h2>{t.registrations}</h2>
          <p>{interpolate(t.registrationsTracked, { count: tournament.registrations.length })}</p>
          <Link className="text-link" href={`/organizer/tournaments/${tournament.id}/registrations`}>
            {t.reviewRegistrations}
          </Link>
        </article>
        <article className="card">
          <h2>{t.schedule}</h2>
          <p>{interpolate(t.gamesConfigured, { count: tournament.games.length })}</p>
          <Link className="text-link" href={`/organizer/tournaments/${tournament.id}/schedule`}>
            {t.manageSchedule}
          </Link>
        </article>
        <article className="card">
          <h2>{t.eventDay}</h2>
          <p>{t.eventDayBody}</p>
          <Link className="text-link" href={`/organizer/tournaments/${tournament.id}/check-in`}>
            {t.openCheckIn}
          </Link>
        </article>
      </section>

      <section className="feature-band">
        <div>
          <span className="step-label">{t.notifications}</span>
          <h2>{t.recentActivity}</h2>
        </div>
        <div className="summary-strip">
          <Link href={`/organizer/tournaments/${tournament.id}/scores`}>{t.scores}</Link>
          <Link href={`/organizer/tournaments/${tournament.id}/standings`}>{t.standings}</Link>
        </div>
      </section>
    </main>
  );
}
