/**
 * Dev seed — fills a local Postgres instance (see docker-compose.yml) with
 * a realistic-ish business so Phase 7's features (price-tracker chart
 * windows, unit recency + 8-cap, invite-owner gating) can be exercised
 * without clicking through the app 20 times.
 *
 * Run with: npm run seed:local  (loads .env.local, points at Docker PG)
 */
import { PrismaClient } from '@prisma/client';
import { buyerService } from '../src/services/buyerService';
import { billService } from '../src/services/billService';

const prisma = new PrismaClient();

// Fixed UUIDs so re-running the seed is idempotent (upserts, not creates).
const OWNER_ID = '11111111-1111-1111-1111-111111111111';
const MEMBER_ID = '22222222-2222-2222-2222-222222222222';
const BUSINESS_ID = '33333333-3333-3333-3333-333333333333';

const DAY = 24 * 60 * 60 * 1000;
const daysAgo = (n: number) => new Date(Date.now() - n * DAY);

async function main() {
  console.log('Seeding local dev data...');

  const owner = await prisma.profile.upsert({
    where: { id: OWNER_ID },
    update: {},
    create: { id: OWNER_ID, fullName: 'रमेश कुमार' },
  });

  const member = await prisma.profile.upsert({
    where: { id: MEMBER_ID },
    update: {},
    create: { id: MEMBER_ID, fullName: 'सुनीता देवी' },
  });

  const business = await prisma.business.upsert({
    where: { id: BUSINESS_ID },
    update: {},
    create: { id: BUSINESS_ID, name: 'रमेश जनरल स्टोर', ownerId: owner.id },
  });

  await prisma.businessMember.upsert({
    where: { businessId_userId: { businessId: business.id, userId: owner.id } },
    update: {},
    create: { businessId: business.id, userId: owner.id, role: 'owner' },
  });
  await prisma.businessMember.upsert({
    where: { businessId_userId: { businessId: business.id, userId: member.id } },
    update: {},
    create: { businessId: business.id, userId: member.id, role: 'member' },
  });

  // Optionally add your real signed-in Supabase user as a member too, so
  // this seeded business shows up when you open the real app.
  const myUserId = process.env.SEED_MEMBER_USER_ID?.trim();
  if (myUserId) {
    await prisma.profile.upsert({
      where: { id: myUserId },
      update: {},
      // fullName gets overwritten by auth.ts on your next real sign-in.
      create: { id: myUserId, fullName: 'आप' },
    });
    await prisma.businessMember.upsert({
      where: { businessId_userId: { businessId: business.id, userId: myUserId } },
      update: {},
      create: { businessId: business.id, userId: myUserId, role: 'member' },
    });
    console.log(`Added SEED_MEMBER_USER_ID (${myUserId}) as a member of the seeded business.`);
  }

  // 11 units, more than the picker's 8-item cap, with varied lastUsedAt so
  // recency sorting is actually visible (Phase 7 §C).
  const unitDefs: { name: string; usedDaysAgo: number | null }[] = [
    { name: 'डिब्बा', usedDaysAgo: 0 },
    { name: 'किग्रा', usedDaysAgo: 1 },
    { name: 'लीटर', usedDaysAgo: 2 },
    { name: 'पीस', usedDaysAgo: 3 },
    { name: 'दर्जन', usedDaysAgo: 5 },
    { name: 'बोरा', usedDaysAgo: 8 },
    { name: 'बोतल', usedDaysAgo: 12 },
    { name: 'पैकेट', usedDaysAgo: 20 },
    { name: 'ग्राम', usedDaysAgo: 30 },
    { name: 'मीटर', usedDaysAgo: null }, // never used — should sort last
    { name: 'रोल', usedDaysAgo: null },
  ];

  const units: Record<string, { id: string; name: string }> = {};
  for (const def of unitDefs) {
    const unit = await prisma.unit.upsert({
      where: { name: def.name },
      update: {},
      create: { name: def.name },
    });
    await prisma.businessUnit.upsert({
      where: { businessId_unitId: { businessId: business.id, unitId: unit.id } },
      update: { lastUsedAt: def.usedDaysAgo == null ? null : daysAgo(def.usedDaysAgo) },
      create: {
        businessId: business.id,
        unitId: unit.id,
        lastUsedAt: def.usedDaysAgo == null ? null : daysAgo(def.usedDaysAgo),
      },
    });
    units[def.name] = unit;
  }

  // Items with different price-history shapes, so the All-time/7-day/
  // month tabs on the detail screen actually show different data:
  //   - आटा: several changes spread over 2 months (all-time shows more
  //     points than the 7-day/month tabs)
  //   - चीनी: changed only in the last week (all tabs show it)
  //   - नमक: never had a price change since creation (single point —
  //     exercises the "not enough data" empty state)
  const itemDefs = [
    {
      name: 'आटा',
      unit: 'किग्रा',
      quantity: 40,
      history: [
        { price: 38, daysAgo: 60 },
        { price: 40, daysAgo: 35 },
        { price: 42, daysAgo: 15 },
        { price: 41, daysAgo: 3 },
      ],
    },
    {
      name: 'चीनी',
      unit: 'किग्रा',
      quantity: 25,
      history: [
        { price: 44, daysAgo: 6 },
        { price: 46, daysAgo: 1 },
      ],
    },
    {
      name: 'नमक',
      unit: 'पैकेट',
      quantity: 60,
      history: [{ price: 20, daysAgo: 45 }],
    },
    {
      name: 'तेल',
      unit: 'लीटर',
      quantity: 15,
      history: [
        { price: 120, daysAgo: 90 },
        { price: 130, daysAgo: 40 },
        { price: 128, daysAgo: 10 },
      ],
    },
    {
      name: 'चावल',
      unit: 'बोरा',
      quantity: 8,
      history: [{ price: 1400, daysAgo: 20 }],
    },
  ];

  const itemsByName: Record<string, { id: string }> = {};

  for (const def of itemDefs) {
    const latest = def.history[def.history.length - 1];
    const createdAt = daysAgo(def.history[0].daysAgo);
    const updatedAt = daysAgo(latest.daysAgo);

    const existing = await prisma.inventoryItem.findFirst({
      where: { businessId: business.id, name: def.name },
    });

    const item = existing
      ? await prisma.inventoryItem.update({
          where: { id: existing.id },
          data: {
            price: latest.price,
            quantity: def.quantity,
            unit: def.unit,
            updatedAt,
            updatedBy: owner.id,
          },
        })
      : await prisma.inventoryItem.create({
          data: {
            businessId: business.id,
            name: def.name,
            price: latest.price,
            quantity: def.quantity,
            unit: def.unit,
            updatedAt,
            updatedBy: owner.id,
            createdAt,
          },
        });
    itemsByName[def.name] = item;

    // Replace price history each run so re-seeding stays consistent.
    // Alternates owner/member as editor so the history list has more
    // than one name to actually exercise the "edited by" column.
    await prisma.inventoryPriceHistory.deleteMany({ where: { itemId: item.id } });
    await prisma.inventoryPriceHistory.createMany({
      data: def.history.map((h, i) => ({
        itemId: item.id,
        price: h.price,
        recordedAt: daysAgo(h.daysAgo),
        editedBy: i % 2 === 0 ? owner.id : member.id,
      })),
    });
  }

  // Buyers/bills/payments — deleted and recreated fresh every run
  // (cascades to their bills/bill_items/payments/deposits) so re-seeding
  // never leaves stale or inconsistent data behind, unlike a plain
  // insert-if-missing approach. Every payment goes through the REAL
  // billService functions (not a raw prisma.billPayment.create) so the
  // seed data can never drift from the actual Deposit invariant every
  // real payment enforces — a bill marked paid always has a matching
  // Deposit row, exactly like a payment made through the app.
  await prisma.buyer.deleteMany({ where: { businessId: business.id } });

  // 1) Simple case: one buyer, one fully-paid bill (single-bill deposit)
  // and one still-unpaid bill.
  const ramBuyer = await buyerService.create(business.id, 'राम प्रसाद');
  await billService.create(business.id, owner.id, {
    buyerId: ramBuyer.id,
    billDate: daysAgo(10),
    items: [{ itemId: itemsByName['आटा'].id, quantity: 5, price: 41 }],
    markPaidNow: true,
  });
  await billService.create(business.id, owner.id, {
    buyerId: ramBuyer.id,
    billDate: daysAgo(2),
    items: [{ itemId: itemsByName['चीनी'].id, quantity: 2, price: 46 }],
    markPaidNow: false,
  });

  // 2) Multi-bill deposit case: 3 bills at staggered dates, then one
  // buyer-level payment that fully settles the oldest and partially
  // settles the middle one, oldest-first (Phase 9/10) — leaves the
  // newest bill untouched and unpaid.
  const sitaBuyer = await buyerService.create(business.id, 'सीता ट्रेडर्स');
  await billService.create(business.id, member.id, {
    buyerId: sitaBuyer.id,
    billDate: daysAgo(8),
    items: [{ itemId: itemsByName['तेल'].id, quantity: 1, price: 80 }],
    markPaidNow: false,
  });
  await billService.create(business.id, member.id, {
    buyerId: sitaBuyer.id,
    billDate: daysAgo(5),
    items: [{ itemId: itemsByName['नमक'].id, quantity: 1, price: 30 }],
    markPaidNow: false,
  });
  await billService.create(business.id, member.id, {
    buyerId: sitaBuyer.id,
    billDate: daysAgo(1),
    items: [{ itemId: itemsByName['चावल'].id, quantity: 1, price: 20 }],
    markPaidNow: false,
  });
  // ₹95: fills the ₹80 oldest bill fully + ₹15 partial on the ₹30 middle
  // one — exercises exactly the जमा list's "one deposit, two settled
  // bills" case end to end.
  await billService.recordBuyerPayment(business.id, sitaBuyer.id, owner.id, 95);

  // 3) Empty-state case: a buyer with no bills at all yet.
  await buyerService.create(business.id, 'गीता स्टोर्स');

  console.log(`Seeded business "${business.name}" (${business.id}) with 5 items, 11 units.`);
  console.log('Seeded 3 buyers: राम प्रसाद (1 paid + 1 unpaid bill), सीता ट्रेडर्स (3 bills, one multi-bill deposit), गीता स्टोर्स (no bills yet).');
  console.log(`Owner profile: ${OWNER_ID}, member profile: ${MEMBER_ID}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
