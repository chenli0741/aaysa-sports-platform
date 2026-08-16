import { PrismaClient, TournamentStatus } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  await prisma.tournament.upsert({
    where: { slug: "aaysa-festival-2026" },
    update: {},
    create: {
      slug: "aaysa-festival-2026",
      name: "AAYSA Festival 2026",
      description: "Initial seed tournament for AAYSA Sports registration and operations development.",
      status: TournamentStatus.DRAFT,
      startsAt: new Date("2026-08-02T00:00:00.000Z"),
      endsAt: new Date("2026-08-23T23:59:59.000Z"),
      divisions: {
        create: [
          {
            name: "5v5 Division",
            minRoster: 5,
            maxRoster: 7
          }
        ]
      }
    }
  });
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
