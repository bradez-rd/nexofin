import Anthropic from '@anthropic-ai/sdk';
import { env } from '../../config/env.js';

/** Superficie mínima del SDK que usa el asistente; permite sustituirla en las pruebas. */
export interface LlmClient {
  messages: {
    create(params: Anthropic.MessageCreateParamsNonStreaming): Promise<Anthropic.Message>;
  };
}

/** Cliente de Claude, o null si no hay ANTHROPIC_API_KEY (entonces el asistente usa su motor de reglas). */
export function createLlmClient(): LlmClient | null {
  if (!env.ANTHROPIC_API_KEY) return null;
  return new Anthropic({ apiKey: env.ANTHROPIC_API_KEY, maxRetries: 2, timeout: 60_000 });
}
