import { Router } from 'express';
import { AccountController } from '../controllers/AccountController.js';
import { AccountService } from '../../application/accounts/AccountService.js';
import { PostgresAccountRepository } from '../../infrastructure/repositories/PostgresAccountRepository.js';
import { authMiddleware } from '../middlewares/auth.middleware.js';
import { validate } from '../middlewares/validate.middleware.js';
import { CreateAccountSchema, UpdateAccountSchema } from '../dtos/index.js';

const router = Router();
const accountRepository = new PostgresAccountRepository();
const accountService = new AccountService(accountRepository);
const accountController = new AccountController(accountService);

// Todas las rutas de cuentas requieren autenticación
router.use(authMiddleware);

router.post('/', validate(CreateAccountSchema), accountController.create);
router.get('/', accountController.list);
router.get('/summary/balances', accountController.getSummary);
router.get('/:id', accountController.getById);
router.put('/:id', validate(UpdateAccountSchema), accountController.update);
router.delete('/:id', accountController.archive);

export default router;
