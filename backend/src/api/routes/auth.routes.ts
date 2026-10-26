import { Router } from 'express';
import { AuthController } from '../controllers/AuthController.js';
import { AuthService } from '../../application/auth/AuthService.js';
import { PostgresUserRepository } from '../../infrastructure/repositories/PostgresUserRepository.js';
import { validate } from '../middlewares/validate.middleware.js';
import { authMiddleware } from '../middlewares/auth.middleware.js';
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
router.post('/login', validate(LoginSchema), authController.login);
router.get('/profile', authMiddleware, authController.getProfile);
router.put(
  '/profile',
  authMiddleware,
  validate(UpdateProfileSchema),
  authController.updateProfile
);

export default router;
