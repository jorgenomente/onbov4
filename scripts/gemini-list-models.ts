export {};

type GeminiModel = {
  name?: string;
  displayName?: string;
  description?: string;
  supportedGenerationMethods?: string[];
  inputTokenLimit?: number;
  outputTokenLimit?: number;
};

type GeminiModelsResponse = {
  models?: GeminiModel[];
};

function requireEnv(name: string) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is not set`);
  }
  return value;
}

function sortByName(a: GeminiModel, b: GeminiModel) {
  return (a.name ?? '').localeCompare(b.name ?? '');
}

async function main() {
  const apiKey = requireEnv('GEMINI_API_KEY');
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`,
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Gemini API error: ${response.status} ${errorText}`);
  }

  const payload = (await response.json()) as GeminiModelsResponse;
  const models = payload.models ?? [];

  const filtered = models.filter((model) => {
    if (!model.supportedGenerationMethods) {
      return true;
    }
    return model.supportedGenerationMethods.includes('generateContent');
  });

  const sorted = filtered.sort(sortByName);

  if (sorted.length === 0) {
    console.log('No models returned.');
    return;
  }

  for (const model of sorted) {
    const supported = model.supportedGenerationMethods
      ? model.supportedGenerationMethods.join(', ')
      : 'unknown';

    console.log('---');
    console.log(`name: ${model.name ?? 'unknown'}`);
    console.log(`displayName: ${model.displayName ?? 'unknown'}`);
    if (model.description) {
      console.log(`description: ${model.description}`);
    }
    console.log(`supportedGenerationMethods: ${supported}`);
    if (typeof model.inputTokenLimit === 'number') {
      console.log(`inputTokenLimit: ${model.inputTokenLimit}`);
    }
    if (typeof model.outputTokenLimit === 'number') {
      console.log(`outputTokenLimit: ${model.outputTokenLimit}`);
    }
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
