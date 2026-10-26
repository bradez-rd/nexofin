import { Request, Response, NextFunction } from 'express';
import { AccountService } from '../../application/accounts/AccountService.js';

export class AccountController {
  constructor(private readonly accountService: AccountService) {}

  public create = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user!.id;
      const account = await this.accountService.createAccount(userId, req.body);
      res.status(201).json({
        success: true,
        message: 'Cuenta financiera creada exitosamente',
        data: { account },
      });
    } catch (err) {
      next(err);
    }
  };

  public list = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user!.id;
      const includeArchived = req.query.incluir_archivadas === 'true';
      const accounts = await this.accountService.listAccounts(userId, includeArchived);
      res.status(200).json({
        success: true,
        data: {
          total: accounts.length,
          accounts,
        },
      });
    } catch (err) {
      next(err);
    }
  };

  public getById = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user!.id;
      const accountId = req.params.id as string;
      const account = await this.accountService.getAccountById(userId, accountId);
      res.status(200).json({
        success: true,
        data: { account },
      });
    } catch (err) {
      next(err);
    }
  };

  public update = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user!.id;
      const accountId = req.params.id as string;
      const account = await this.accountService.updateAccount(userId, accountId, req.body);
      res.status(200).json({
        success: true,
        message: 'Cuenta financiera actualizada exitosamente',
        data: { account },
      });
    } catch (err) {
      next(err);
    }
  };

  public archive = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user!.id;
      const accountId = req.params.id as string;
      const account = await this.accountService.archiveAccount(userId, accountId);
      res.status(200).json({
        success: true,
        message: 'Cuenta financiera archivada correctamente',
        data: { account },
      });
    } catch (err) {
      next(err);
    }
  };

  public getSummary = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user!.id;
      const summary = await this.accountService.getBalancesSummary(userId);
      res.status(200).json({
        success: true,
        data: { summary },
      });
    } catch (err) {
      next(err);
    }
  };
}
