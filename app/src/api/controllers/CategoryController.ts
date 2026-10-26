import { Request, Response, NextFunction } from 'express';
import { ICategoryRepository } from '../../domain/repositories/index.js';
import { ValidationError } from '../../domain/errors/DomainError.js';

export class CategoryController {
  constructor(private readonly categoryRepository: ICategoryRepository) {}

  public list = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user!.id;
      const tipo = req.query.tipo as 'ingreso' | 'gasto' | undefined;
      const categories = await this.categoryRepository.findAllForUser(userId, tipo);
      res.status(200).json({
        success: true,
        data: {
          total: categories.length,
          categories,
        },
      });
    } catch (err) {
      next(err);
    }
  };

  public create = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user!.id;
      const { nombre, tipo, icono, color } = req.body;

      if (!nombre || !tipo) {
        throw new ValidationError('Nombre y tipo son obligatorios');
      }

      if (!['ingreso', 'gasto'].includes(tipo)) {
        throw new ValidationError('El tipo de categoría debe ser ingreso o gasto');
      }

      const category = await this.categoryRepository.create(
        userId,
        nombre.trim(),
        tipo,
        icono,
        color
      );

      res.status(201).json({
        success: true,
        message: 'Categoría personalizada creada exitosamente',
        data: { category },
      });
    } catch (err) {
      next(err);
    }
  };
}
