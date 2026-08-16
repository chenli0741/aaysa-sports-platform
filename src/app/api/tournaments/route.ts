import { NextResponse } from "next/server";
import { getTournaments } from "@/lib/tournaments";

export async function GET() {
  const tournaments = await getTournaments();

  return NextResponse.json({
    data: tournaments.map((tournament) => ({
      id: tournament.id,
      slug: tournament.slug,
      name: tournament.name,
      description: tournament.description,
      status: tournament.status,
      startsAt: tournament.startsAt,
      endsAt: tournament.endsAt,
      divisionCount: tournament.divisions.length,
      sessionCount: tournament.sessions.length,
      registrationCount: tournament.registrations.length
    }))
  });
}
