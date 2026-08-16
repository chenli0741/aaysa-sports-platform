import { prisma } from "@/lib/prisma";

export async function getTournaments() {
  return prisma.tournament.findMany({
    orderBy: [{ startsAt: "asc" }, { createdAt: "desc" }],
    include: {
      divisions: true,
      sessions: { orderBy: { startsAt: "asc" } },
      venues: true,
      registrations: true
    }
  });
}

export async function getTournamentBySlug(slug: string) {
  return prisma.tournament.findUnique({
    where: { slug },
    include: {
      divisions: { orderBy: { name: "asc" } },
      sessions: { orderBy: { startsAt: "asc" } },
      venues: {
        include: { fields: { orderBy: { name: "asc" } } },
        orderBy: { name: "asc" }
      },
      games: {
        include: {
          division: true,
          field: { include: { venue: true } },
          homeTeam: true,
          awayTeam: true
        },
        orderBy: { startsAt: "asc" }
      },
      standings: {
        include: { team: true, division: true },
        orderBy: [{ points: "desc" }, { goalDiff: "desc" }, { goalsFor: "desc" }]
      },
      registrations: {
        include: {
          team: { include: { club: true } },
          division: true,
          rosterEntries: { orderBy: { createdAt: "asc" } },
          payments: { orderBy: { createdAt: "desc" } }
        },
        orderBy: { createdAt: "desc" }
      }
    }
  });
}

export async function getOrganizerTournament(id: string) {
  return prisma.tournament.findUnique({
    where: { id },
    include: {
      divisions: true,
      sessions: { orderBy: { startsAt: "asc" } },
      venues: { include: { fields: true } },
      games: {
        include: {
          division: true,
          field: { include: { venue: true } },
          homeTeam: true,
          awayTeam: true
        },
        orderBy: { startsAt: "asc" }
      },
      registrations: {
        include: {
          team: { include: { club: true } },
          division: true,
          rosterEntries: true,
          payments: true
        },
        orderBy: { createdAt: "desc" }
      },
      standings: {
        include: { team: true, division: true },
        orderBy: [{ points: "desc" }, { goalDiff: "desc" }, { goalsFor: "desc" }]
      },
      notifications: { orderBy: { createdAt: "desc" }, take: 10 }
    }
  });
}
