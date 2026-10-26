import { Router } from 'express';
import { TransactionController } from '../controllers/TransactionController.js';
import { TransactionService } from '../../application/transactions/TransactionService.js';
import { PostgresTransactionRepository } from '../../infrastructure/repositories/PostgresTransactionRepository.js';
import { PostgresAccountRepository } from '../../infrastructure/repositories/PostgresAccountRepository.js';
import { PostgresCategoryRepository } from '../../infrastructure/repositories/PostgresCategoryRepository.js';
import { authMiddleware } from '../middlewares/auth.middleware.js';
import { validate } from '../middlewares/validate.middleware.js';
import {
  CreateTransactionSchema,
  CreateTransferSchema,
  UpdateTransactionSchema,
  TransactionQuerySchema,
} from '../dtos/index.js';

const router = Router();
const transactionRepository = new PostgresTransactionRepository();
const accountRepository = new PostgresAccountRepository();
const categoryRepository = new PostgresCategoryRepository();

const transactionService = new TransactionService(
  transactionRepository,
  accountRepository,
  categoryRepository
);
const transactionController = new TransactionController(transactionService);

// Todas las rutas de transacciones requieren autenticación
router.use(authMiddleware);

router.post('/', validate(CreateTransactionSchema), transactionController.create);
router.post('/transfer', validate(CreateTransferSchema), transactionController.createTransfer);
router.get('/', validate(TransactionQuerySchema, 'query'), transactionController.list);
router.get('/summary/monthly', transactionController.getMonthlySummary);
router.get('/:id', transactionController.getById);
router.put('/:id', validate(UpdateTransactionSchema), transactionController.update);
router.delete('/:id', transactionController.delete);

export default router;
