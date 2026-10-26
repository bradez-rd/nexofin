import { app } from './app.js';
import { env } from './config/env.js';
import { db } from './infrastructure/database/db.js';

async function bootstrap() {
  try {
    console.log('----------------------------------------------------');
    console.log('🚀 Iniciando servidor NexoFin AI API...');
    console.log(`🌍 Entorno: ${env.NODE_ENV}`);
    console.log(`⏱️  Zona horaria: ${env.TIMEZONE}`);

    // Inicializar esquema relacional y semillas en la base de datos
    await db.initSchema();

    const server = app.listen(env.PORT, () => {
      console.log(`🟢 Servidor activo y escuchando en http://localhost:${env.PORT}`);
      console.log(`📊 Endpoint de Salud: http://localhost:${env.PORT}/api/v1/health`);
      console.log('----------------------------------------------------');
    });

    const shutdown = async (signal: string) => {
      console.log(`\n🛑 Recibida señal ${signal}. Cerrando servidor graceful...`);
      server.close(async () => {
        await db.close();
        console.log('👋 Conexiones cerradas. Salida completada.');
        process.exit(0);
      });
    };

    process.on('SIGINT', () => shutdown('SIGINT'));
    process.on('SIGTERM', () => shutdown('SIGTERM'));
  } catch (error) {
    console.error('❌ Error fatal al iniciar el servidor:', error);
    process.exit(1);
  }
}

bootstrap();
