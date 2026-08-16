import { NextRequest, NextResponse } from "next/server";
import { getRequestI18n } from "@/lib/i18n-request";
import { getTournamentBySlug } from "@/lib/tournaments";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ slug: string }> }
) {
  const { dictionary } = getRequestI18n(request);
  const { slug } = await params;
  const tournament = await getTournamentBySlug(slug);

  if (!tournament) {
    return NextResponse.json({ error: dictionary.apiErrors.tournamentNotFound }, { status: 404 });
  }

  return NextResponse.json({
    data: tournament.standings.map((standing) => ({
      id: standing.id,
      division: standing.division.name,
      team: standing.team.name,
      played: standing.played,
      wins: standing.wins,
      draws: standing.draws,
      losses: standing.losses,
      goalsFor: standing.goalsFor,
      goalsAgainst: standing.goalsAgainst,
      goalDiff: standing.goalDiff,
      points: standing.points
    }))
  });
}
