import { notFound } from "next/navigation";
import { CheckInPanel } from "@/components/check-in-panel";
import { getI18n } from "@/lib/i18n-server";
import { getOrganizerTournament } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function CheckInPage({
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
    <main className="main wide">
      <section className="hero">
        <div className="eyebrow">{t.openCheckIn}</div>
        <h1>{tournament.name}</h1>
        <p className="lead">{t.checkInLead}</p>
      </section>

      <CheckInPanel registrations={tournament.registrations} locale={locale} />
    </main>
  );
}
