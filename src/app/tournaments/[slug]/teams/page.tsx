import { notFound } from "next/navigation";
import { RegistrationTable } from "@/components/registration-table";
import { getTournamentBySlug } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function TeamsPage({
  params
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const tournament = await getTournamentBySlug(slug);

  if (!tournament) {
    notFound();
  }

  return (
    <main className="main wide">
      <section className="hero">
        <div className="eyebrow">Teams</div>
        <h1>{tournament.name}</h1>
        <p className="lead">Public team registration status summary.</p>
      </section>

      <RegistrationTable registrations={tournament.registrations} />
    </main>
  );
}
