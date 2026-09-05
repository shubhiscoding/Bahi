import { prisma } from '../prisma';

// डिब्बा/बोतल match Flutter's Strings.unitBox/unitBottle; बोरी (sack) has
// no matching Strings constant today — these are free-form Unit names,
// not required to mirror a Strings constant. Every new business gets
// these 3 linked. (Previously डिब्बा/किग्रा/लीटर — changed per updated
// decision.)
const SEED_UNIT_NAMES = ['बोरी', 'डिब्बा', 'बोतल'];

export const unitService = {
  // Sorted by recency (last used on an item) — never-used units (null)
  // sort after ones with real usage. Drives the unit picker's recency
  // sort + 8-item cap on the Flutter side (Phase 7 §C).
  async listForBusiness(businessId: string) {
    const links = await prisma.businessUnit.findMany({
      where: { businessId },
      include: { unit: true },
      orderBy: { lastUsedAt: { sort: 'desc', nulls: 'last' } },
    });
    return links.map((l) => ({ id: l.unit.id, name: l.unit.name }));
  },

  /**
   * Adds a unit to a business's list. Upserts into the global `units`
   * catalog by unique name first (so two businesses adding the same name
   * independently share one row), then links it — idempotent if already
   * linked.
   */
  async addUnit(businessId: string, name: string) {
    const trimmed = name.trim();
    if (!trimmed) throw new Error('EMPTY_UNIT_NAME');

    const unit = await prisma.unit.upsert({
      where: { name: trimmed },
      update: {},
      create: { name: trimmed },
    });

    await prisma.businessUnit.upsert({
      where: { businessId_unitId: { businessId, unitId: unit.id } },
      update: {},
      create: { businessId, unitId: unit.id },
    });

    return { id: unit.id, name: unit.name };
  },

  /** Called once from businessService.create() right after a business is made. */
  async ensureDefaultUnitsLinked(businessId: string) {
    for (const name of SEED_UNIT_NAMES) {
      await this.addUnit(businessId, name);
    }
  },
};
