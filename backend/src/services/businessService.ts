import { prisma } from '../prisma';
import { generateInviteCode } from '../utils/inviteCode';

export const businessService = {
  async create(ownerId: string, name: string) {
    // Retry a few times on the unlikely event of an invite code collision
    for (let attempt = 0; attempt < 5; attempt++) {
      const inviteCode = generateInviteCode();
      try {
        return await prisma.business.create({
          data: {
            name,
            ownerId,
            inviteCode,
            members: {
              create: { userId: ownerId, role: 'owner' },
            },
          },
        });
      } catch (err: any) {
        if (err.code === 'P2002') continue; // unique constraint on inviteCode — retry
        throw err;
      }
    }
    throw new Error('Failed to generate a unique invite code');
  },

  async joinByCode(userId: string, inviteCode: string) {
    const business = await prisma.business.findUnique({
      where: { inviteCode: inviteCode.toUpperCase() },
    });

    if (!business) {
      throw new Error('CODE_NOT_FOUND');
    }

    const existing = await prisma.businessMember.findUnique({
      where: { businessId_userId: { businessId: business.id, userId } },
    });
    if (existing) {
      return business; // already a member — idempotent
    }

    await prisma.businessMember.create({
      data: { businessId: business.id, userId, role: 'member' },
    });

    return business;
  },

  async listForUser(userId: string) {
    const memberships = await prisma.businessMember.findMany({
      where: { userId },
      include: { business: true },
    });
    return memberships.map((m) => m.business);
  },

  async getById(businessId: string) {
    return prisma.business.findUnique({ where: { id: businessId } });
  },

  async delete(businessId: string) {
    await prisma.business.delete({ where: { id: businessId } });
  },

  async listMembers(businessId: string) {
    const members = await prisma.businessMember.findMany({
      where: { businessId },
      include: { user: true },
      orderBy: { joinedAt: 'asc' },
    });
    return members.map((m) => ({
      userId: m.userId,
      businessId: m.businessId,
      role: m.role,
      joinedAt: m.joinedAt,
      fullName: m.user.fullName,
    }));
  },

  async removeMember(businessId: string, userId: string) {
    await prisma.businessMember.delete({
      where: { businessId_userId: { businessId, userId } },
    });
  },
};
