import { Router } from 'express';
import { AuthController } from '../controllers/AuthController.js';
import { AuthService } from '../../application/auth/AuthService.js';
import { SecurityService } from '../../application/auth/SecurityService.js';
import { PostgresUserRepository } from '../../infrastructure/repositories/PostgresUserRepository.js';
import { validate } from '../middlewares/validate.middleware.js';
import { authMiddleware } from '../middlewares/auth.middleware.js';
import { rateLimit } from '../middlewares/rateLimit.middleware.js';
import { handler, ok } from '../http.js';
import { env } from '../../config/env.js';
import {
  RegisterSchema,
  LoginSchema,
  UpdateProfileSchema,
  ForgotPasswordSchema,
  ResetPasswordSchema,
  ChangePasswordSchema,
  VerifyEmailSchema,
  TwoFactorEnableSchema,
  PasswordConfirmSchema,
  DeleteAccountSchema,
  ConsentSchema,
} from '../dtos/index.js';

const router = Router();
const userRepository = new PostgresUserRepository();
const authService = new AuthService(userRepository);
const authController = new AuthController(authService);
const security = new SecurityService();

router.post('/register', validate(RegisterSchema), authController.register);
// RNF-SEG-06: limita los intentos de inicio de sesión por origen
const loginLimiter = rateLimit({
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  max: env.RATE_LIMIT_LOGIN_MAX,
  message: 'Demasiados intentos de inicio de sesión. Espera un minuto e inténtalo de nuevo.',
});

router.post('/login', loginLimiter, validate(LoginSchema), authController.login);
router.post(
  '/logout',
  authMiddleware,
  handler(async (req, res) => {
    await authService.logout(req.user!.id, req.user!.token);
    ok(res, {}, 'Sesión cerrada');
  })
);
router.get('/profile', authMiddleware, authController.getProfile);
router.put('/profile', authMiddleware, validate(UpdateProfileSchema), authController.updateProfile);

// Recuperación y cambio de contraseña (RF-AUT-05/06)
router.post(
  '/forgot-password',
  loginLimiter,
  validate(ForgotPasswordSchema),
  handler(async (req, res) => {
    const result = await security.requestPasswordReset(req.body.email);
    ok(res, result, 'Si el correo está registrado, recibirás un enlace para restablecer tu contraseña (vence en 30 minutos)');
  })
);
router.post(
  '/reset-password',
  loginLimiter,
  validate(ResetPasswordSchema),
  handler(async (req, res) => {
    await security.resetPassword(req.body.token, req.body.password);
    ok(res, {}, 'Contraseña restablecida. Inicia sesión con la nueva contraseña');
  })
);
router.post(
  '/change-password',
  authMiddleware,
  validate(ChangePasswordSchema),
  handler(async (req, res) => {
    await security.changePassword(req.user!.id, req.user!.token, req.body.password_actual, req.body.password_nueva);
    ok(res, {}, 'Contraseña actualizada. Las demás sesiones fueron cerradas');
  })
);

// Verificación de correo (RF-AUT-02)
router.post(
  '/verify-email/request',
  authMiddleware,
  handler(async (req, res) => ok(res, await security.requestEmailVerification(req.user!.id), 'Enlace de verificación enviado'))
);
router.post(
  '/verify-email',
  validate(VerifyEmailSchema),
  handler(async (req, res) => {
    await security.verifyEmail(req.body.token);
    ok(res, {}, 'Correo verificado');
  })
);

// Autenticación en dos pasos (RF-AUT-07)
router.post(
  '/2fa/setup',
  authMiddleware,
  handler(async (req, res) => ok(res, await security.twoFactorSetup(req.user!.id, req.user!.email)))
);
router.post(
  '/2fa/enable',
  authMiddleware,
  validate(TwoFactorEnableSchema),
  handler(async (req, res) => {
    await security.twoFactorEnable(req.user!.id, req.body.codigo);
    ok(res, {}, 'Verificación en dos pasos activada');
  })
);
router.post(
  '/2fa/disable',
  authMiddleware,
  validate(PasswordConfirmSchema),
  handler(async (req, res) => {
    await security.twoFactorDisable(req.user!.id, req.body.password);
    ok(res, {}, 'Verificación en dos pasos desactivada');
  })
);

// Consentimiento para el asistente, exportación y baja (RF-ASI, RF-AUT-09/10)
router.put(
  '/consent-ai',
  authMiddleware,
  validate(ConsentSchema),
  handler(async (req, res) =>
    ok(res, { consentimiento_ia_en: await security.setAiConsent(req.user!.id, req.body.otorgado) })
  )
);
router.get(
  '/export',
  authMiddleware,
  handler(async (req, res) => {
    const data = await security.exportData(req.user!.id);
    res.setHeader('Content-Disposition', 'attachment; filename="nexofin_mis_datos.json"');
    ok(res, data);
  })
);
router.delete(
  '/account',
  authMiddleware,
  validate(DeleteAccountSchema),
  handler(async (req, res) => {
    await security.deleteAccount(req.user!.id, req.body.password, req.body.confirmacion);
    ok(res, {}, 'Tu cuenta y tus datos fueron eliminados');
  })
);

export default router;
