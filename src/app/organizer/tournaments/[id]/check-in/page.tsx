import { notFound } from "next/navigation";
import { RegistrationTable } from "@/components/registration-table";
import { getOrganizerTournament } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function CheckInPage({
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
        <div className="eyebrow">Check-in</div>
        <h1>{tournament.name}</h1>
        <p className="lead">QR and manual check-in will write to CheckIn records. First version exposes readiness before scanning.</p>
      </section>

      <RegistrationTable registrations={tournament.registrations} />
    </main>
  );
}
