<p align="center"><img src="Resources/AppIconSource.png" width="112" height="112" alt="Icône de Talis"></p>

[English](README.md) | [简体中文](README.zh-CN.md) | [Español](README.es.md) | [Português do Brasil](README.pt-BR.md) | [日本語](README.ja.md) | [Français](README.fr.md) | [हिन्दी](README.hi.md)

# Talis

Clarifiez votre idée, puis transmettez-la à l’IA.

Talis est un espace de travail de prompts pour macOS. Notez une idée, créez un prompt que vous pourrez continuer à modifier, puis copiez-le dans l’outil d’IA que vous utilisez déjà. Répondez à des questions pour préciser les éléments importants ou enregistrez des besoins récurrents comme modèles personnels.

Les révisions successives utilisent les 3 derniers tours comme contexte. Ouvrez **Historique des révisions** pour retrouver les entrées et résultats de la session en cours. Utilisez **Effacer** pour commencer une nouvelle tâche.

Après une révision par l’IA, continuez à écrire ou cliquez sur **±** pour voir les ajouts et les suppressions. Fermez la comparaison pour retrouver votre brouillon avec vos propres modifications.

## Installation

### Installer depuis le DMG

Téléchargez [Talis v1.1.0 DMG](https://github.com/viowai/7viow-talis/releases/download/v1.1.0/talis-v1.1.0-macos-arm64-build44.dmg). Ouvrez l’image disque, faites glisser `Talis.app` vers **Applications**, puis lancez l’app depuis ce dossier. Talis nécessite un Mac Apple Silicon et macOS 13 ou ultérieur.

L’app est signée ad hoc et n’a pas été notariée par Apple. Si macOS bloque le premier lancement, vérifiez que le téléchargement provient de ce dépôt et, si l’option est proposée, choisissez **Ouvrir quand même** dans **Réglages Système → Confidentialité et sécurité**. Consultez les [instructions d’Apple pour le premier lancement](https://support.apple.com/en-us/102445).

La compilation depuis les sources nécessite les outils Xcode 26 ou ultérieurs, dont le SDK macOS 26 ou ultérieur. La compilation est vérifiée sur Apple Silicon ; Intel n’a pas été vérifié. Aucun abonnement payant Apple Developer n’est nécessaire. Le projet ne dépend d’aucun Swift Package tiers.

### Installer depuis les sources

Dans Terminal :

```bash
git clone https://github.com/viowai/7viow-talis.git
cd 7viow-talis
bash scripts/install_app.sh && open /Applications/Talis.app
```

Si les outils de développement Apple sont absents, lancez `xcode-select --install` et suivez l’invite système. Si Talis est ouvert, enregistrez votre texte et quittez l’app avant l’installation. Les modèles personnels et les réglages sont conservés hors du paquet de l’app.

## Première utilisation

Vous pouvez modifier et copier des prompts sans configurer de clé API :

1. Ouvrez Talis et appuyez sur `Option + Space`.
2. Saisissez votre demande, appuyez sur `Command + Return` pour la copier, puis collez-la dans votre outil d’IA.

Pour modifier un texte avec l’IA, ouvrez **Réglages du service d’IA** depuis le bouton en forme d’engrenage. Choisissez **Clé API** ou **Abonnement**, sélectionnez un service et une région, puis enregistrez. Dans l’éditeur, choisissez **Affiner**, **Réécrire** ou **Questionner**. Le résultat reste modifiable ; utilisez **Copier le prompt Cmd+Return** une fois prêt.

## Services d’IA et données

La modification, le choix de modèles et la copie fonctionnent hors ligne. Les fonctions Affiner, Réécrire, Questionner et la création de modèles par IA nécessitent un service accessible. Les fournisseurs avec clé API facturent selon leurs propres conditions. Le mode Abonnement utilise l’abonnement au produit d’IA déjà connecté sur ce Mac, sans clé API distincte.

Les clés API sont stockées dans le trousseau macOS, séparément pour chaque fournisseur. Le mode Abonnement utilise le produit connecté localement et ne copie ni n’enregistre son jeton OAuth. La disponibilité des modèles, comptes, régions et quotas dépend de chaque service. Consultez [les réglages des services d’IA](docs/ai-services.en.md) et [la confidentialité et les données](docs/privacy.en.md).

Talis copie du texte dans le presse-papiers. Il n’envoie pas de requêtes à votre place et ne transfère pas de pièces jointes. Prompt Service et Talis Codex ne sont pas inclus dans cette version de bureau.

## Retours et licence

Pour signaler un problème, créez une [GitHub Issue](https://github.com/viowai/7viow-talis/issues) avec la version de l’app, celle de macOS, le type de puce, les étapes et les détails de l’erreur. Retirez les clés API et les données privées avant l’envoi.

Mainteneur : Viow. Le code source et la documentation originale sont sous [Apache License 2.0](LICENSE), Copyright 2026 Wenbin Li. Consultez [NOTICE](NOTICE) et [les avis tiers](THIRD-PARTY-NOTICES.md). Montserrat est distribuée sous SIL Open Font License 1.1.
