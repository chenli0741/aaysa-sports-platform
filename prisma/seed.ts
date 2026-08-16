import {
  GameStatus,
  LegalDocumentType,
  PaymentStatus,
  PrismaClient,
  PromoDiscountType,
  TournamentStatus
} from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const tournament = await prisma.tournament.upsert({
    where: { slug: "aaysa-festival-2026" },
    update: {
      status: TournamentStatus.REGISTRATION_OPEN
    },
    create: {
      slug: "aaysa-festival-2026",
      name: "AAYSA Festival 2026",
      description: "Initial seed tournament for AAYSA Sports registration and operations development.",
      status: TournamentStatus.REGISTRATION_OPEN,
      startsAt: new Date("2026-08-02T00:00:00.000Z"),
      endsAt: new Date("2026-08-23T23:59:59.000Z"),
      sessions: {
        create: [
          { name: "Session 1", startsAt: new Date("2026-08-02T16:00:00.000Z") },
          { name: "Session 2", startsAt: new Date("2026-08-09T16:00:00.000Z") },
          { name: "Session 3", startsAt: new Date("2026-08-16T16:00:00.000Z") },
          { name: "Session 4", startsAt: new Date("2026-08-23T16:00:00.000Z") }
        ]
      },
      divisions: {
        create: [
          {
            name: "5v5 Division",
            minBirthDate: new Date("2014-01-01T00:00:00.000Z"),
            maxBirthDate: new Date("2018-12-31T23:59:59.000Z"),
            minRoster: 5,
            maxRoster: 7
          }
        ]
      },
      venues: {
        create: [
          {
            name: "AAYSA Sports Complex",
            address: "San Jose, CA",
            fields: {
              create: [{ name: "Field 1" }, { name: "Field 2" }]
            }
          }
        ]
      }
    }
  });

  const division = await prisma.division.findFirstOrThrow({
    where: { tournamentId: tournament.id }
  });

  await prisma.legalDocument.upsert({
    where: { id: "seed-waiver-aaysa-festival-2026" },
    update: {},
    create: {
      id: "seed-waiver-aaysa-festival-2026",
      type: LegalDocumentType.WAIVER,
      version: "2026.1",
      title: "AAYSA Sports Tournament Waiver",
      body: "Guardian accepts participation, medical, media, and event operations terms for the registered player."
    }
  });

  await prisma.promoCode.upsert({
    where: { code: "AAYSA25" },
    update: {},
    create: {
      tournamentId: tournament.id,
      divisionId: division.id,
      code: "AAYSA25",
      discountType: PromoDiscountType.FIXED_AMOUNT,
      amountCents: 2500,
      maxUses: 100,
      active: true
    }
  });

  const club = await prisma.club.upsert({
    where: { name: "AAYSA Demo Club" },
    update: {},
    create: { name: "AAYSA Demo Club" }
  });

  const dragons = await prisma.team.upsert({
    where: { id: "seed-team-dragons" },
    update: {},
    create: { id: "seed-team-dragons", name: "Dragons U11", clubId: club.id }
  });

  const lightning = await prisma.team.upsert({
    where: { id: "seed-team-lightning" },
    update: {},
    create: { id: "seed-team-lightning", name: "Lightning U11", clubId: club.id }
  });

  const field = await prisma.field.findFirstOrThrow({
    where: { venue: { tournamentId: tournament.id } }
  });

  await prisma.game.upsert({
    where: { id: "seed-game-opening" },
    update: {},
    create: {
      id: "seed-game-opening",
      tournamentId: tournament.id,
      divisionId: division.id,
      fieldId: field.id,
      homeTeamId: dragons.id,
      awayTeamId: lightning.id,
      startsAt: new Date("2026-08-02T17:00:00.000Z"),
      status: GameStatus.SCHEDULED,
      publishedAt: new Date()
    }
  });

  await prisma.registration.upsert({
    where: { id: "seed-registration-dragons" },
    update: {},
    create: {
      id: "seed-registration-dragons",
      tournamentId: tournament.id,
      divisionId: division.id,
      teamId: dragons.id,
      status: "WAIVER_INCOMPLETE",
      baseAmountCents: 38000,
      discountCents: 2500,
      feeCents: 1200,
      totalCents: 36700,
      rosterEntries: {
        create: [
          { firstName: "Alex", lastName: "Chen", dob: new Date("2016-03-02T00:00:00.000Z"), guardianName: "Demo Guardian", guardianEmail: "guardian@example.com", waiverStatus: "SIGNED", eligibilityStatus: "ELIGIBLE" },
          { firstName: "Ben", lastName: "Park", dob: new Date("2016-06-10T00:00:00.000Z"), guardianName: "Demo Guardian", guardianEmail: "guardian@example.com", waiverStatus: "SIGNED", eligibilityStatus: "ELIGIBLE" },
          { firstName: "Casey", lastName: "Lee", dob: new Date("2015-08-14T00:00:00.000Z"), guardianName: "Demo Guardian", guardianEmail: "guardian@example.com", waiverStatus: "SIGNED", eligibilityStatus: "ELIGIBLE" },
          { firstName: "Drew", lastName: "Singh", dob: new Date("2016-01-21T00:00:00.000Z"), guardianName: "Demo Guardian", guardianEmail: "guardian@example.com", waiverStatus: "SIGNED", eligibilityStatus: "ELIGIBLE" },
          { firstName: "Evan", lastName: "Kim", dob: new Date("2015-11-05T00:00:00.000Z"), guardianName: "Demo Guardian", guardianEmail: "guardian@example.com", waiverStatus: "MISSING", eligibilityStatus: "ELIGIBLE" }
        ]
      },
      payments: {
        create: {
          amountCents: 36700,
          status: PaymentStatus.PENDING
        }
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
