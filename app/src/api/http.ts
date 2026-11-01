import { Request, Response, NextFunction, RequestHandler } from 'express';

type Handler = (req: Request, res: Response) => Promise<void>;

/** Envuelve un controlador asíncrono para delegar los errores al middleware global. */
export function handler(fn: Handler): RequestHandler {
  return (req: Request, res: Response, next: NextFunction) => {
    fn(req, res).catch(next);
  };
}

export function ok(res: Response, data: unknown, message?: string, status = 200): void {
  res.status(status).json({ success: true, ...(message ? { message } : {}), data });
}
