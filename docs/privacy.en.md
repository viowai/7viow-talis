# Privacy and Data

[简体中文](privacy.md) | [English](privacy.en.md)

## What Leaves the Mac

Editing, template selection, and copying are handled locally. When you choose **Refine**, **Rewrite**, **Grill-me**, or generate a reusable template, Talis sends the input, recent context, or Grill-me answers needed for that operation to the model service you selected.

API-key requests go directly from the app to the selected provider endpoint. A custom endpoint receives the request at the URL you entered. Subscription mode sends requests through the trusted local shared gateway; Talis does not read or save any product OAuth token. The desktop app does not connect to a Talis account server, telemetry service, or crash-reporting service. Each model provider processes received requests under its own policy.

To keep model versions current, Talis may query the selected provider's model API or public model catalog when AI is used. Public catalog requests do not contain an API key, user text, or conversation context. Authenticated model-list requests use only the selected provider's key. Catalog results are cached locally.

**Stop** cancels the local wait and ignores late results. A request already sent to a provider may already be processing; stopping does not retract content that has left the Mac.

## Local Storage

Personal templates and system-template overrides are stored in `~/Library/Application Support/Talis`. Provider, endpoint, resolved model IDs, and catalog refresh times are stored in app preferences.

Ordinary drafts and editing history exist only in the current app process. Escape, closing the window, or the global shortcut ends the current quick session. The latest text and revision history can be explicitly restored during the same process. Quitting the app does not persist the ordinary draft.

API keys are stored separately by provider in macOS Keychain and are not written to preferences or a new plaintext configuration. The settings field masks a newly entered key and never displays a saved key. Switching providers clears an unsubmitted input. Save failures are reported explicitly; Talis does not delete an existing key first and risk losing it when the replacement write fails.

During an upgrade from an older version, Talis reads the old configuration in its existing priority order. It removes an active plaintext key from preferences or configuration only after the Keychain write has been read back successfully. Different old keys are kept as recovery items for their matching providers and are not silently reused for another provider. Any migration failure preserves the uncleared old input and shows an error.

**Remove API Key** deletes only the selected provider's key and matching old recovery item after confirmation. Other providers are unchanged. A removed key is not restored automatically from old configuration. Independently retained backups may still contain old configuration; treat them as private material and do not place them in a public repository or feedback attachment.

## Sharing and Feedback

You decide which tool receives copied text. For support, include the operation, app version, macOS version, and a redacted input. Remove API keys, client material, and personal information.
