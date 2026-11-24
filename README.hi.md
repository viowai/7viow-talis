<p align="center"><img src="Resources/AppIconSource.png" width="112" height="112" alt="Talis ऐप आइकन"></p>

[English](README.md) | [简体中文](README.zh-CN.md) | [Español](README.es.md) | [Português do Brasil](README.pt-BR.md) | [日本語](README.ja.md) | [Français](README.fr.md) | [हिन्दी](README.hi.md)

# Talis

अपनी बात स्पष्ट लिखें, फिर उसे AI को दें।

Talis macOS के लिए Prompt कार्यस्थल है। कोई विचार लिखें, ऐसा Prompt बनाएँ जिसे आप आगे संपादित कर सकें, और उसे अपने पसंदीदा AI टूल में कॉपी करें। ज़रूरी जानकारी कम हो तो सवालों के जवाब देकर उसे पूरा करें, या बार-बार इस्तेमाल होने वाली ज़रूरतों को निजी टेम्पलेट के रूप में सहेजें।

लगातार संशोधन में पिछली 3 राउंड का संदर्भ लिया जाता है। मौजूदा सत्र के इनपुट और नतीजे देखने के लिए **Revision History** खोलें। नया काम शुरू करने के लिए एडिटर में **Clear** चुनें।

AI के संशोधन के बाद आप एडिटर में लिखना जारी रख सकते हैं। **±** पर क्लिक करके देखें कि AI ने क्या जोड़ा या हटाया। तुलना बंद करने पर आपका ड्राफ़्ट आपके अपने बदलावों के साथ वापस दिखता है। Talis के सभी समर्थित मॉडलों में ड्राफ़्ट को दोबारा लिखते या सँवारते समय आप जवाब आते ही उसे एडिटर में पढ़ सकते हैं।

## इंस्टॉल करें

### DMG से इंस्टॉल करें

[Talis v1.1.1 DMG](https://github.com/viowai/7viow-talis/releases/download/v1.1.1/talis-v1.1.1-macos-arm64-build45.dmg) डाउनलोड करें। डिस्क इमेज खोलें, `Talis.app` को **Applications** में खींचें, फिर वहीं से ऐप खोलें। Apple Silicon वाला Mac और macOS 13 या नया संस्करण आवश्यक है।

ऐप ad-hoc हस्ताक्षरित है और Apple द्वारा notarized नहीं है। पहली बार खोलते समय macOS रोक दे, तो पुष्टि करें कि ऐप इसी repository से डाउनलोड किया है। विकल्प उपलब्ध हो तो **System Settings → Privacy & Security** में **Open Anyway** चुनें। [Apple के पहली बार खोलने के निर्देश](https://support.apple.com/en-us/102445) देखें।

स्रोत से बनाने के लिए macOS 26 SDK सहित Xcode 26 या नए developer tools चाहिए। Apple Silicon पर build सत्यापित है; Intel पर सत्यापित नहीं है। सशुल्क Apple Developer सदस्यता की ज़रूरत नहीं है। परियोजना में तीसरे पक्ष की Swift Package निर्भरताएँ नहीं हैं।

### स्रोत से इंस्टॉल करें

Mac के Terminal में चलाएँ:

```bash
git clone https://github.com/viowai/7viow-talis.git
cd 7viow-talis
bash scripts/install_app.sh && open /Applications/Talis.app
```

Apple developer tools न हों, तो `xcode-select --install` चलाकर सिस्टम के निर्देश पूरे करें। Talis खुला हो तो अपना टेक्स्ट सहेजें और इंस्टॉल करने से पहले ऐप बंद करें। निजी टेम्पलेट और सेटिंग ऐप पैकेज से अलग सुरक्षित रहते हैं।

## पहली बार इस्तेमाल

API Key सेट किए बिना Prompt संपादित और कॉपी किया जा सकता है:

1. Talis खोलें और `Option + Space` दबाएँ।
2. अपना अनुरोध लिखें, कॉपी करने के लिए `Command + Return` दबाएँ और उसे AI टूल में पेस्ट करें।

AI से संशोधन कराने के लिए गियर बटन से **AI Service Settings** खोलें। **API Key** या **Subscription** चुनें, सेवा और क्षेत्र चुनकर सेटिंग सहेजें। एडिटर में लौटकर **Refine**, **Rewrite** या **Grill-me** चुनें। नतीजा संपादित किया जा सकता है। तैयार होने पर **Copy Prompt Cmd+Return** चुनें।

## AI सेवाएँ और डेटा

संपादन, टेम्पलेट चुनना और कॉपी करना ऑफलाइन काम करते हैं। Refine, Rewrite, Grill-me और AI से टेम्पलेट बनाने के लिए उपलब्ध सेवा से कनेक्शन चाहिए। API Key वाले प्रदाता अपने नियमों के अनुसार शुल्क लेते हैं। Subscription मोड इस Mac पर पहले से साइन इन किए AI उत्पाद की सदस्यता इस्तेमाल करता है; अलग API Key नहीं चाहिए।

API Key macOS Keychain में हर प्रदाता के लिए अलग सहेजी जाती है। Subscription मोड स्थानीय रूप से साइन इन किए उत्पाद का उपयोग करता है और उसका OAuth token कॉपी या सहेजता नहीं है। मॉडल, खाते, क्षेत्र और उपयोग-सीमा की उपलब्धता सेवा पर निर्भर करती है। [AI सेवा सेटिंग](docs/ai-services.en.md) और [गोपनीयता व डेटा](docs/privacy.en.md) देखें।

Talis टेक्स्ट को clipboard में कॉपी करता है। यह आपकी ओर से AI अनुरोध नहीं भेजता और संलग्न फ़ाइलें स्थानांतरित नहीं करता। Prompt Service और Talis Codex इस desktop संस्करण में शामिल नहीं हैं।

## प्रतिक्रिया और लाइसेंस

समस्या बताने के लिए [GitHub Issue](https://github.com/viowai/7viow-talis/issues) बनाएँ। ऐप और macOS संस्करण, chip का प्रकार, समस्या तक पहुँचने के कदम और त्रुटि का विवरण दें। भेजने से पहले API Key और निजी जानकारी हटा दें।

रखरखावकर्ता: Viow। स्रोत कोड और मूल दस्तावेज़ [Apache License 2.0](LICENSE), Copyright 2026 Wenbin Li के अंतर्गत हैं। [NOTICE](NOTICE) और [तीसरे पक्ष के नोटिस](THIRD-PARTY-NOTICES.md) देखें। Montserrat फ़ॉन्ट SIL Open Font License 1.1 के अंतर्गत वितरित है।
