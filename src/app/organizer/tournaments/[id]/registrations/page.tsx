import { notFound } from "next/navigation";
import { RegistrationTable } from "@/components/registration-table";
import { getOrganizerTournament } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function OrganizerRegistrationsPage({
  params
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const tournament = await getOrganizerTournament(id);

  if (!tournament) {
    notFound();
  }

  return (
    <main className="main wide">
      <section className="hero">
        <div className="eyebrow">Organizer registrations</div>
        <h1>{tournament.name}</h1>
        <p className="lead">Readiness table: team, division, roster, payment, waivers, eligibility, status.</p>
      </section>

      <RegistrationTable registrations={tournament.registrations} />
    </main>
  );
}
