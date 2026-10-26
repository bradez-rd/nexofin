import { Request, Response, NextFunction } from 'express';
import { TransactionService } from '../../application/transactions/TransactionService.js';

export class TransactionController {
  constructor(private readonly transactionService: TransactionService) {}

  public create = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user!.id;
      const transaction = await this.transactionService.createTransaction(userId, req.body);
      res.status(201).json({
        success: true,
        message: 'Transacción registrada exitosamente',
        data: { transaction },
      });
    } catch (err) {
      next(err);
    }
  };

  public createTransfer = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const userId = req.user!.id;
      const result = await this.transactionService.createTransfer(userId, req.body);
      res.status(201).json({
        success: true,
        message: 'Transferencia atómica registrada exitosamente entre cuentas',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  };

  public list = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user!.id;
      const result = await this.transactionService.listTransactions(userId, req.query as any);
      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  };

  public getById = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user!.id;
      const transactionId = req.params.id as string;
      const transaction = await this.transactionService.getTransactionById(userId, transactionId);
      res.status(200).json({
        success: true,
        data: { transaction },
      });
    } catch (err) {
      next(err);
    }
  };

  public update = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user!.id;
      const transactionId = req.params.id as string;
      const transaction = await this.transactionService.updateTransaction(
        userId,
        transactionId,
        req.body
      );
      res.status(200).json({
        success: true,
        message: 'Transacción actualizada y valor previo archivado en historial',
        data: { transaction },
      });
    } catch (err) {
      next(err);
    }
  };

  public delete = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user!.id;
      const transactionId = req.params.id as string;
      await this.transactionService.deleteTransaction(userId, transactionId);
      res.status(200).json({
        success: true,
        message: 'Transacción eliminada lógicamente de forma exitosa',
      });
    } catch (err) {
      next(err);
    }
  };

  public getMonthlySummary = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const userId = req.user!.id;
      const year = parseInt(req.query.anio as string || new Date().getFullYear().toString(), 10);
      const month = parseInt(req.query.mes as string || (new Date().getMonth() + 1).toString(), 10);

      const summary = await this.transactionService.getMonthlySummary(userId, year, month);
      res.status(200).json({
        success: true,
        data: summary,
      });
    } catch (err) {
      next(err);
    }
  };
}
