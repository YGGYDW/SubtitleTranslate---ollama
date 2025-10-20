string GetDesc() {
    return "使用本地Ollama部署模型实现实时字幕翻译";
}
string GetLoginDesc() {
    return "{$CP0=第一行填入模型名称，第二行密码留空。$}";
}
string UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36";
string api_url   = "http://127.0.0.1:11434/v1/chat/completions";
string context   = "";
array<string> LangTable = {
    "Auto","zh","zh-TW", "ja", "ko","en", "fr", "de", "es", "ru", "ar", "fa", "he"
};
array<string> GetSrcLangs() { return LangTable; }
array<string> GetDstLangs() { return LangTable; }
bool IsModelInstalled(string modelName) {
    string response = HostUrlGetString("http://127.0.0.1:11434/api/tags", UserAgent, "", "");
    if (response.empty()) return false;
    JsonReader Reader;
    JsonValue Root;
    if (!Reader.parse(response, Root)) return false;
    JsonValue models = Root["models"];
    if (!models.isArray()) return false;

    for (uint i = 0; i < models.size(); ++i) {
        if (models[i]["name"].isString() && models[i]["name"].asString() == modelName) {
            return true;
        }
    }
    return false;
}
string ServerLogin(string User, string Pass) {
    string model = User.Trim();
    if (model.empty()) {
        HostPrintUTF8("{$CP950=模型名称未填写。$}{$CP0=Model name not entered.$}\n");
        HostSaveString("selected_model_ollama", "");
        return "失败";
    }
    if (!IsModelInstalled(model)) {
        HostPrintUTF8("{$CP950=模型未安装，请检查模型名称是否正确。$}{$CP0=Model not installed. Please check the name.$}\n");
        HostSaveString("selected_model_ollama", "");
        return "失败";
    }
    HostSaveString("selected_model_ollama", model);
    HostPrintUTF8("{$CP950=模型名称已成功配置。$}{$CP0=Model name successfully configured.$}\n");
    return "200 ok";
}
void ServerLogout() {
    HostSaveString("selected_model_ollama", "");
    HostPrintUTF8("{$CP950=已成功登出。$}{$CP0=Successfully logged out.$}\n");
}
string JsonEscape(const string &in input) {
    string output = input;
    output.replace("\\", "\\\\");
    output.replace("\"", "\\\"");
    output.replace("\n", "\\n");
    output.replace("\r", "\\r");
    output.replace("\t", "\\t");
    return output;
}
string Translate(string Text, string &in SrcLang, string &in DstLang) {
    string selected_model = HostLoadString("selected_model_ollama", "");
    if (selected_model.empty() || !IsModelInstalled(selected_model)) {
        HostPrintUTF8("{$CP950=模型名称无效，无法翻译。$}{$CP0=Invalid model name. Translation aborted.$}\n");
        return "";
    }
    if (DstLang.empty() || DstLang == "Auto") {
        HostPrintUTF8("{$CP950=目标语言未指定。$}{$CP0=Target language not specified.$}\n");
        return "";
    }
    string UNICODE_RLE = "\u202B";
    if (SrcLang.empty() || SrcLang == "Auto") SrcLang = "";
    string prompt = "你将扮演一名专业的翻译，请将以下字幕文本翻译";
    if (!SrcLang.empty()) prompt += "从" + SrcLang;
    prompt += "翻译成" + DstLang + "。请注意：\n";
    prompt += "1. 保持原文的语气和风格\n";
    prompt += "2. 确保译文与上下文保持连贯\n";
    prompt += "3. 只需提供译文，无需解释\n\n";
    if (!context.empty()) {
        prompt += "上下文参考：\n'''\n" + context + "\n'''\n\n";
    }
    prompt += "待翻译文本：\n'''\n" + Text + "\n'''";
    string escapedPrompt = JsonEscape(prompt);
    string requestData   = "{\"model\":\"" + selected_model + "\",\"messages\":[{\"role\":\"user\",\"content\":\"" + escapedPrompt + "\"}]}";
    string headers       = "Content-Type: application/json";
    string response = HostUrlGetString(api_url, UserAgent, headers, requestData);
    if (response.empty()) {
        HostPrintUTF8("{$CP950=翻译请求失败。$}{$CP0=Translation request failed.$}\n");
        return "";
    }
    JsonReader Reader;
    JsonValue Root;
    if (!Reader.parse(response, Root)) {
        HostPrintUTF8("{$CP950=无法解析 API 回应。$}{$CP0=Failed to parse API response.$}\n");
        return "";
    }
    JsonValue choices = Root["choices"];
    if (choices.isArray() && choices[0]["message"]["content"].isString()) {
        string translatedText = choices[0]["message"]["content"].asString();
        if (DstLang == "fa" || DstLang == "ar" || DstLang == "he") {
            translatedText = UNICODE_RLE + translatedText;
        }
        SrcLang = "UTF8";
        DstLang = "UTF8";
        return translatedText;
    }
    HostPrintUTF8("{$CP950=翻译失败。$}{$CP0=Translation failed.$}\n");
    return "";
}