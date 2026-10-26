import { Request, Response, NextFunction } from 'express';
import { AuthService } from '../../application/auth/AuthService.js';

export class AuthController {
  constructor(private readonly authService: AuthService) {}

  public register = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const result = await this.authService.register(req.body);
      res.status(201).json({
        success: true,
        message: 'Usuario registrado exitosamente',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  };

  public login = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const result = await this.authService.login(req.body);
      res.status(200).json({
        success: true,
        message: 'Inicio de sesión exitoso',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  };

  public getProfile = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user!.id;
      const user = await this.authService.getProfile(userId);
      res.status(200).json({
        success: true,
        data: { user },
      });
    } catch (err) {
      next(err);
    }
  };

  public updateProfile = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user!.id;
      const updated = await this.authService.updateProfile(userId, req.body);
      res.status(200).json({
        success: true,
        message: 'Perfil actualizado exitosamente',
        data: { user: updated },
      });
    } catch (err) {
      next(err);
    }
  };
}
