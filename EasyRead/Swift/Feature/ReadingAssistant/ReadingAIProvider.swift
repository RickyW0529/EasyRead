// Copyright © 2026 EasyRead contributors. GPL-3.0.
import Foundation

/// Public chat-completion presets ported from BranchReport's model-provider catalog.
/// Deployment-specific addresses and non-chat models are intentionally excluded.
struct ReadingAIProvider: Identifiable, Sendable {
    enum Reasoning: Sendable {
        case providerDefault, thinkingType, enableThinking
    }

    static let all: [ReadingAIProvider] = [
        .init(
            id: "openai",
            name: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            models: ["gpt-4.1", "gpt-4o"],
            reasoning: .providerDefault
        ),
        .init(
            id: "deepseek",
            name: "DeepSeek",
            baseURL: "https://api.deepseek.com/v1",
            models: ["deepseek-v4-flash", "deepseek-v4-pro", "deepseek-chat"],
            reasoning: .thinkingType
        ),
        .init(
            id: "zhipu",
            name: "智谱 GLM",
            baseURL: "https://open.bigmodel.cn/api/paas/v4",
            models: ["glm-5.1"],
            reasoning: .enableThinking
        ),
        .init(
            id: "zhipu_coding",
            name: "智谱 GLM Coding Plan",
            baseURL: "https://open.bigmodel.cn/api/coding/paas/v4",
            models: ["glm-5.1"],
            reasoning: .enableThinking
        ),
        .init(
            id: "kimi",
            name: "Kimi",
            baseURL: "https://api.moonshot.cn/v1",
            models: ["kimi-k2.7-code", "kimi-k3"],
            reasoning: .enableThinking
        ),
        .init(
            id: "minimax",
            name: "MiniMax",
            baseURL: "https://api.minimaxi.com/v1",
            models: ["MiniMax-M2.7"],
            reasoning: .enableThinking
        ),
        .init(
            id: "stepfun",
            name: "阶跃星辰",
            baseURL: "https://api.stepfun.com/v1",
            models: ["step-3.5-flash", "step-3.5-flash-2603"],
            reasoning: .providerDefault
        ),
        .init(
            id: "bailian",
            name: "阿里云百炼",
            baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
            models: ["qwen3-coder-plus", "qwen3-max"],
            reasoning: .enableThinking
        ),
        .init(
            id: "doubao",
            name: "豆包 / 火山方舟",
            baseURL: "https://ark.cn-beijing.volces.com/api/v3",
            models: ["doubao-seed-2-1-pro-260628"],
            reasoning: .thinkingType
        ),
        .init(
            id: "longcat",
            name: "LongCat",
            baseURL: "https://api.longcat.chat/openai/v1",
            models: ["LongCat-2.0"],
            reasoning: .thinkingType
        ),
        .init(
            id: "mimo",
            name: "小米 MiMo",
            baseURL: "https://api.xiaomimimo.com/v1",
            models: ["mimo-v2.5-pro", "mimo-v2.5"],
            reasoning: .enableThinking
        ),
        .init(
            id: "bailing",
            name: "蚂蚁百灵",
            baseURL: "https://api.tbox.cn/v1",
            models: ["Ling-2.5-1T"],
            reasoning: .enableThinking
        ),
        .init(
            id: "siliconflow",
            name: "硅基流动",
            baseURL: "https://api.siliconflow.cn/v1",
            models: ["Pro/MiniMaxAI/MiniMax-M2.7"],
            reasoning: .enableThinking
        ),
        .init(
            id: "openrouter",
            name: "OpenRouter",
            baseURL: "https://openrouter.ai/api/v1",
            models: ["openai/gpt-4.1", "deepseek/deepseek-chat"],
            reasoning: .providerDefault
        ),
        .init(
            id: "modelscope",
            name: "ModelScope",
            baseURL: "https://api-inference.modelscope.cn/v1",
            models: ["ZhipuAI/GLM-5.1"],
            reasoning: .enableThinking
        ),
        .init(
            id: "custom",
            name: "Custom",
            baseURL: "",
            models: [],
            reasoning: .providerDefault
        ),
    ]

    let id: String
    let name: String
    let baseURL: String
    let models: [String]
    let reasoning: Reasoning

    var requiresAPIKey: Bool { id != "custom" }
    var displayName: String { id == "custom" ? String(localized: "reading.ai.custom_provider") : name }

    static func provider(id: String) -> ReadingAIProvider {
        all.first { $0.id == id } ?? all.first { $0.id == "deepseek" }!
    }
}
