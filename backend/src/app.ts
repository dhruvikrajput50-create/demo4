import express from 'express';
import fs from 'fs';

import path from 'path';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import { corsMiddleware } from './middleware/cors';
import { performanceLogger } from './middleware/performanceLogger';
import { router } from './routes';
import { errorHandler } from './middleware/errorHandler';

export function createApp() {
  const app = express();

  app.use(helmet({
    contentSecurityPolicy: false,
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  }));
  app.use(corsMiddleware);
  app.use(compression());
  app.use(performanceLogger);
  app.use(morgan('dev'));
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true }));

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
  });

  // Serve uploaded files (public, no auth required)
  app.use('/uploads', (_req, res, next) => {
    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    res.setHeader('Cache-Control', 'public, max-age=86400');
    next();
  }, express.static(path.join(__dirname, '../uploads')));

  app.use('/api/v1', router);

  // Serve frontend static files in production
  const frontendPath = path.join(__dirname, '../../frontend/dist');
  
  // Use a more robust check for frontend existence
  const hasFrontend = fs.existsSync(path.join(frontendPath, 'index.html'));

  if (hasFrontend) {
    app.use(express.static(frontendPath));
    app.get('*', (req, res, next) => {
      // Don't serve index.html for API routes that aren't found
      if (req.url.startsWith('/api/') || req.url.startsWith('/uploads/')) {
        return next();
      }
      res.sendFile(path.join(frontendPath, 'index.html'));
    });
  } else {
    // Fallback for production when frontend is not built/copying incorrectly
    app.get('/', (_req, res) => {
      res.json({ 
        message: 'Producteev API is running', 
        frontend_status: 'not_found',
        has_frontend: false,
        path_checked: frontendPath
      });
    });
  }


  app.use(errorHandler);

  return app;
}
