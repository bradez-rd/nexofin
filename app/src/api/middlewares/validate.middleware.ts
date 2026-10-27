import { Request, Response, NextFunction } from 'express';
import { ZodSchema, ZodError } from 'zod';
import { ValidationError } from '../../domain/errors/DomainError.js';

export function validate(schema: ZodSchema, target: 'body' | 'query' | 'params' = 'body') {
  return (req: Request, res: Response, next: NextFunction): void => {
    try {
      const parsed = schema.parse(req[target]);
      // Express 5: req.query es de solo lectura, se redefine la propiedad
            Object.defineProperty(req, target, { value: parsed, writable: true, configurable: true, enumerable: true });
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        const formatted = error.issues.map((issue) => ({
          field: issue.path.join('.'),
          message: issue.message,
        }));
        return next(new ValidationError('Error de validación en la petición', formatted));
      }
      next(error);
    }
  };
}
