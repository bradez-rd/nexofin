import { Router } from 'express';
import authRoutes from './auth.routes.js';
import accountRoutes from './account.routes.js';
import transactionRoutes from './transaction.routes.js';
import categoryRoutes from './category.routes.js';
import healthRoutes from './health.routes.js';
import debtRoutes from './debt.routes.js';
import recurringRoutes from './recurring.routes.js';
import budgetRoutes from './budget.routes.js';
import goalRoutes from './goal.routes.js';
import notificationRoutes from './notification.routes.js';
import auditRoutes from './audit.routes.js';

const router = Router();

router.use('/auth', authRoutes);
router.use('/accounts', accountRoutes);
router.use('/transactions', transactionRoutes);
router.use('/categories', categoryRoutes);
router.use('/debts', debtRoutes);
router.use('/recurring', recurringRoutes);
router.use('/budgets', budgetRoutes);
router.use('/goals', goalRoutes);
router.use('/notifications', notificationRoutes);
router.use('/audit', auditRoutes);
router.use('/health', healthRoutes);

export default router;
