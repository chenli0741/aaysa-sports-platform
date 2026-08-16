import { notFound } from "next/navigation";
import { RegistrationForm } from "@/components/registration-form";
import { getI18n } from "@/lib/i18n-server";
import { getTournamentBySlug } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function RegisterPage({
  params
}: {
  params: Promise<{ slug: string }>;
}) {
  const { locale, dictionary } = await getI18n();
  const t = dictionary.registrationPage;
  const { slug } = await params;
  const tournament = await getTournamentBySlug(slug);

  if (!tournament) {
    notFound();
  }

  return (
    <main className="main wide">
      <section className="hero">
        <div className="eyebrow">{t.eyebrow}</div>
        <h1>{tournament.name}</h1>
        <p className="lead">{t.lead}</p>
      </section>

      <RegistrationForm
        tournamentSlug={tournament.slug}
        locale={locale}
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
