# AI Service Settings

[简体中文](ai-services.md) | [English](ai-services.en.md)

Open **AI Service Settings** from the gear button in the main window, the app menu, or `Command + ,`.

1. Choose **API Key** or **Subscription** as the authentication method.
2. In API Key mode, select a provider and region. Subscription mode lists every service currently exposed by the local shared gateway. New source installations default to DeepSeek.
3. Choose **Get API Key**, create or view a key in the provider console, enter it in Talis, and save. An existing key is never displayed. Saving with the field blank keeps it.
4. Return to the editor and use **Refine**, **Rewrite**, **Grill-me**, or generate a template.

For a business-specific URL or compatible service, choose **Custom Endpoint** as the region and enter the complete HTTPS base URL from the provider console. The endpoint receives the provider key and the content needed for the request. Do not enter a specific model name when the service is handled by Talis.

Subscription mode does not require an API key. Talis reads the services currently exposed by `127.0.0.1:3425/v1/models`, groups them by service, and selects a current text model for each. It does not read, copy, or save product login files or OAuth tokens. If the gateway cannot be reached, only the verified Codex fallback remains.

## Supported Services

API Key mode: DeepSeek, Kimi, MiniMax, OpenAI API, Anthropic, Google, xAI, Tencent Hunyuan, Baidu ERNIE, Alibaba Qwen, ByteDance Doubao, and Zhipu GLM.

Subscription mode dynamically lists services exposed by the local gateway. On this Mac the verified list currently contains Codex, OpenAI, Kimi Work and DeepSeek. The exact list and subscription rights remain controlled by the gateway and service accounts.

Quotas and subscription rights remain controlled by each provider.

## Model Updates

Talis prefers official rolling model aliases. Providers without one may be refreshed from a provider model list or public catalog when AI is used, at most once every 24 hours. Selection is limited to current standard text models in the configured efficiency or regular family and avoids preview, experimental, and high-cost accelerated tiers.

If catalog discovery fails, Talis keeps the existing choice. If a model is explicitly retired, Talis may refresh once and choose a replacement from the same provider. Auth, quota, rate-limit, and network errors are shown directly and do not trigger a silent provider or paid-key switch.

Provider API changes, model naming changes, or family repositioning can still require an app update.

## Updates and Key Retention

Updating the app preserves templates, settings, and API keys stored in macOS Keychain. Switching providers clears an unsaved new-key field. Each provider has a separate key.

Opening Settings or switching providers only checks whether a Keychain item exists; it does not read the secret merely to display status. Using, saving, or migrating a key can still cause macOS to request access. To replace a key, enter a new value and save. **Remove API Key** affects only the currently selected provider after confirmation.
