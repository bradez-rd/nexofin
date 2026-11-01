import { Router } from 'express';
import { AuthController } from '../controllers/AuthController.js';
import { AuthService } from '../../application/auth/AuthService.js';
import { PostgresUserRepository } from '../../infrastructure/repositories/PostgresUserRepository.js';
import { validate } from '../middlewares/validate.middleware.js';
import { authMiddleware } from '../middlewares/auth.middleware.js';
import { rateLimit } from '../middlewares/rateLimit.middleware.js';
import { env } from '../../config/env.js';
import {
  RegisterSchema,
  LoginSchema,
  UpdateProfileSchema,
} from '../dtos/index.js';

const router = Router();
const userRepository = new PostgresUserRepository();
const authService = new AuthService(userRepository);
const authController = new AuthController(authService);

router.post('/register', validate(RegisterSchema), authController.register);
// RNF-SEG-06: limita los intentos de inicio de sesión por origen
const loginLimiter = rateLimit({
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  max: env.RATE_LIMIT_LOGIN_MAX,
  message: 'Demasiados intentos de inicio de sesión. Espera un minuto e inténtalo de nuevo.',
});

router.post('/login', loginLimiter, validate(LoginSchema), authController.login);
router.get('/profile', authMiddleware, authController.getProfile);
router.put(
  '/profile',
  authMiddleware,
  validate(UpdateProfileSchema),
  authController.updateProfile
);

export default router;
