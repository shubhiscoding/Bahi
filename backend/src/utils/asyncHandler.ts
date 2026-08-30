import { Request, Response, NextFunction, RequestHandler } from 'express';

/**
 * Wraps an async route handler so a thrown/rejected error is forwarded to
 * Express's error-handling middleware via next(err) instead of becoming an
 * unhandled promise rejection — which otherwise crashes the entire Node
 * process (Express 4 does not catch async errors automatically).
 */
export function asyncHandler(fn: RequestHandler): RequestHandler {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}
