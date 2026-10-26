import { Router } from 'express';
import authRoutes from './auth.routes.js';
import accountRoutes from './account.routes.js';
import transactionRoutes from './transaction.routes.js';
import categoryRoutes from './category.routes.js';
import healthRoutes from './health.routes.js';

const router = Router();

router.use('/auth', authRoutes);
router.use('/accounts', accountRoutes);
router.use('/transactions', transactionRoutes);
router.use('/categories', categoryRoutes);
router.use('/health', healthRoutes);

export default router;
