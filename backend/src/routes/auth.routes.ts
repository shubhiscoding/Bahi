import { Router } from 'express';
import { requireAuth, upsertProfileFromAuth } from '../middleware/auth';
import { asyncHandler } from '../utils/asyncHandler';
import { profileService } from '../services/profileService';

export const authRoutes = Router();

// Called by the Flutter app right after every successful sign-in.
authRoutes.post(
  '/sync',
  requireAuth,
  asyncHandler(async (req, res) => {
    const profile = await upsertProfileFromAuth(req.user!);
    res.json(profile);
  }),
);

authRoutes.get(
  '/me',
  requireAuth,
  asyncHandler(async (req, res) => {
    res.json(req.user);
  }),
);

authRoutes.put(
  '/profile',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { fullName } = req.body;
    if (!fullName || typeof fullName !== 'string') {
      return res.status(400).json({ error: 'INVALID_NAME' });
    }
    try {
      const profile = await profileService.updateProfile(req.user!.id, fullName);
      res.json(profile);
    } catch (err: any) {
      if (err.message === 'EMPTY_NAME') {
        return res.status(400).json({ error: 'EMPTY_NAME' });
      }
      if (err.message === 'NAME_TOO_LONG') {
        return res.status(400).json({ error: 'NAME_TOO_LONG' });
      }
      throw err;
    }
  }),
);
