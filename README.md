# jingcai-betting

竞彩足球的 **Claude Code 赛前分析 skill（极简版）**：**读用户提供的赔率（截图或文字）** → 去水算公平概率 → 国际比价 + 泊松反推找错价 → 情报校验 → 出方案（含命中概率、梯度、比分串）。

只做「**看盘出方案**」一件事——**赔率一律由用户提供（赔率截图或赔率文字），本工具不抓取任何彩票官网**；也不含投注台账、赛果通知、复盘等运营闭环。方法论（去水、比价、泊松反推、比分串模板）已**内联进 skill**（`skills/jingcai-betting-loop/references/`），开箱即用，无需作者的个人 memory。

> ⚠️ **免责声明**：所有方案均为**负期望值**（让球/大小盘约 −12.9% 起，比分盘约 −40%），仅供理性娱乐。本 skill 只做分析，不替你下单、不鼓励加码。请遵守当地法律，量力而行。

---

## 安装

```
/plugin marketplace add WorldPea/jingcai-betting
/plugin install jingcai-betting@jingcai-betting
```

安装后，把**赔率截图或赔率文字**发给 Claude（带上队名与开赛时间），或直接说「分析这几场」，即触发分析管线。

## 前置依赖（需自行安装/配置）

本 skill 编排了若干外部能力，**未内置**，请自行准备：

| 依赖 | 用途 | 必需性 |
|---|---|---|
| **the-odds-api key** | 多家书商 h2h+spreads+totals 共识（分析核心数据源） | **强烈推荐** |
| `polymarket` / `kalshi` skill | 预测市场真金概率（第二/三验证源） | 推荐 |
| `betting` skill | 赔率转换、EV 计算 | 推荐 |
| `football-data` skill | 赛程 / xG / 伤停 | 可选 |
| `sports-skills` CLI（`markets` / `news` 子命令） | 双预测市场一键匹配、结构化球队情报 | 可选 |

## 配置：the-odds-api key

到 <https://the-odds-api.com> 注册（免费层 500 次/月），把 key 存到约定路径并收紧权限：

```bash
mkdir -p ~/.claude/jingcai
echo 'YOUR_API_KEY' > ~/.claude/jingcai/odds-api.key
chmod 600 ~/.claude/jingcai/odds-api.key
```

skill 在「国际比价」步骤会从该文件读取 key 拉取多家盘口共识。不配置也能跑（退化为只用体彩去水 + 截图/WebSearch），但分析质量会下降。

## 结构

```
.claude-plugin/
  marketplace.json     # marketplace 清单
  plugin.json          # plugin 清单
skills/jingcai-betting-loop/
  SKILL.md             # 赛前分析主流程 + 比分串方案模板
  references/
    method.md          # 五步分析管线（去水 / 比价 / 泊松 / 情报 / 出方案）
    format.md          # 方案输出格式硬性要求（整十金额、命中概率、梯度、比分串）
```

## License

MIT
