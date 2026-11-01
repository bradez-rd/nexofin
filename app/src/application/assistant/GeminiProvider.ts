import { env } from '../../config/env.js';
import {
  AssistantLlm,
  ASSISTANT_SYSTEM_PROMPT,
  HistoryMessage,
  LOOP_EXHAUSTED_TEXT,
  MAX_TOOL_ITERATIONS,
  REFUSAL_TEXT,
  TOOL_SPECS,
  ToolExecutor,
  TurnResult,
} from './AssistantLlm.js';

// Subconjunto de la API REST de Gemini (generateContent) que usa el asistente.
export interface GeminiPart {
  text?: string;
  thought?: boolean;
  functionCall?: { name: string; args?: Record<string, unknown>; id?: string };
  functionResponse?: { name: string; id?: string; response: Record<string, unknown> };
  [other: string]: unknown; // p. ej. thoughtSignature: se devuelve tal cual
}
export interface GeminiContent {
  role: 'user' | 'model';
  parts: GeminiPart[];
}
export interface GeminiResponse {
  candidates?: { content?: GeminiContent; finishReason?: string }[];
  promptFeedback?: { blockReason?: string };
}

/** Cliente mínimo de Gemini; permite sustituirlo en las pruebas. */
export interface GeminiClient {
  generateContent(model: string, body: Record<string, unknown>): Promise<GeminiResponse>;
}

/** Cliente HTTP real (Google AI Studio). La clave viaja en el encabezado, nunca en la URL. */
export class GeminiHttpClient implements GeminiClient {
  constructor(
    private readonly apiKey: string,
    private readonly baseUrl = 'https://generativelanguage.googleapis.com/v1beta'
  ) {}

  public async generateContent(model: string, body: Record<string, unknown>): Promise<GeminiResponse> {
    const res = await fetch(`${this.baseUrl}/models/${encodeURIComponent(model)}:generateContent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': this.apiKey },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(60_000),
    });
    if (!res.ok) {
      const detail = await res.json().catch(() => ({}));
      throw new Error(`Gemini respondió ${res.status}: ${detail?.error?.message ?? res.statusText}`);
    }
    return (await res.json()) as GeminiResponse;
  }
}

const GEMINI_TOOLS = [
  {
    functionDeclarations: TOOL_SPECS.map((t) => ({ name: t.name, description: t.description, parametersJsonSchema: t.parameters })),
  },
];

/** Proveedor Gemini (Google): bucle de llamadas a funciones; tiene capa gratuita en Google AI Studio. */
export class GeminiProvider implements AssistantLlm {
  public readonly name = 'gemini' as const;

  constructor(private readonly client: GeminiClient) {}

  public async runTurn(history: HistoryMessage[], userMessage: string, execute: ToolExecutor): Promise<TurnResult> {
    const contents: GeminiContent[] = [
      ...history.map((h) => ({ role: (h.role === 'user' ? 'user' : 'model') as 'user' | 'model', parts: [{ text: h.content }] })),
      { role: 'user', parts: [{ text: userMessage }] },
    ];
    const toolsUsed: string[] = [];

    for (let i = 0; i < MAX_TOOL_ITERATIONS; i++) {
      const response = await this.client.generateContent(env.GEMINI_MODEL, {
        systemInstruction: { parts: [{ text: ASSISTANT_SYSTEM_PROMPT }] },
        contents,
        tools: GEMINI_TOOLS,
        generationConfig: { temperature: 0.3, maxOutputTokens: 2048 },
      });

      const candidate = response.candidates?.[0];
      const blocked =
        Boolean(response.promptFeedback?.blockReason) || candidate?.finishReason === 'SAFETY' || candidate?.finishReason === 'PROHIBITED_CONTENT';
      if (blocked) return { text: REFUSAL_TEXT, toolsUsed, refused: true };
      if (!candidate?.content) throw new Error('Gemini no devolvió contenido');

      // Se conserva el turno del modelo tal cual (incluye las firmas de razonamiento que Gemini 3 exige devolver)
      contents.push({ role: 'model', parts: candidate.content.parts ?? [] });
      const parts = candidate.content.parts ?? [];
      const calls = parts.filter((p) => p.functionCall);

      if (calls.length === 0) {
        const text = parts
          .filter((p) => typeof p.text === 'string' && !p.thought)
          .map((p) => p.text as string)
          .join('\n')
          .trim();
        return { text, toolsUsed, refused: false };
      }

      const results: GeminiPart[] = [];
      for (const part of calls) {
        const call = part.functionCall!;
        toolsUsed.push(call.name);
        let output: Record<string, unknown>;
        try {
          const r = await execute(call.name, call.args ?? {});
          output = r.isError ? { error: r.content } : { output: r.content };
        } catch (e: any) {
          output = { error: `No se pudo ejecutar la herramienta: ${e?.message ?? 'error'}` };
        }
        results.push({ functionResponse: { name: call.name, ...(call.id ? { id: call.id } : {}), response: output } });
      }
      contents.push({ role: 'user', parts: results });
    }
    return { text: LOOP_EXHAUSTED_TEXT, toolsUsed, refused: false };
  }
}
