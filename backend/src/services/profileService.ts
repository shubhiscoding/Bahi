import { prisma } from '../prisma';

export const profileService = {
  async updateProfile(userId: string, fullName: string) {
    const trimmed = fullName.trim();
    if (!trimmed) throw new Error('EMPTY_NAME');
    if (trimmed.length > 100) throw new Error('NAME_TOO_LONG');

    return prisma.profile.update({
      where: { id: userId },
      data: { fullName: trimmed },
    });
  },
};
