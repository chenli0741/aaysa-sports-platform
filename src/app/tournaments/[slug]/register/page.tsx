import { notFound } from "next/navigation";
import { RegistrationForm } from "@/components/registration-form";
import { getTournamentBySlug } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function RegisterPage({
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
        <div className="eyebrow">Registration</div>
        <h1>{tournament.name}</h1>
        <p className="lead">Submit team manager details, division, roster, guardian waiver status, promo code, and payment readiness.</p>
      </section>

      <RegistrationForm
        tournamentSlug={tournament.slug}
        divisions={tournament.divisions.map((division) => ({
          id: division.id,
          name: division.name,
          minRoster: division.minRoster,
          maxRoster: division.maxRoster,
          minBirthDate: division.minBirthDate?.toISOString() ?? null,
          maxBirthDate: division.maxBirthDate?.toISOString() ?? null
        }))}
      />
    </main>
  );
}
