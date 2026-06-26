# jingcai-betting

中国体彩竞彩足球投注的 **Claude Code 全流程闭环 skill**：赛前多源分析 → 投注台账 → 赛果通知 → 复盘 → 优化沉淀。

方法论（去水、国际比价、泊松反推、比分串方案、门禁清单）已**内联进 skill**（`skills/jingcai-betting-loop/references/`），开箱即用——无需作者的个人 memory。

> ⚠️ **免责声明**：所有方案均为**负期望值**（让球/大小盘约 −12.9% 起，比分盘约 −40%），仅供理性娱乐。本 skill 只做分析与记录，不替你下单、不鼓励加码。请遵守当地法律，量力而行。

---

## 安装

```
/plugin marketplace add WorldPea/jingcai-betting
/plugin install jingcai-betting@jingcai-betting
```

安装后，跟 Claude 说「分析周四这几场」、发体彩赔率截图、或报场次编号（如「周六006」），即触发分析管线。

## 前置依赖（需自行安装/配置）

本 skill 编排了若干外部能力，**未内置**，请自行准备：

| 依赖 | 用途 | 必需性 |
|---|---|---|
| `betting` skill | 赔率转换、Kelly 仓位计算 | 推荐 |
| `polymarket` / `kalshi` skill | 预测市场真金概率（第二/三验证源） | 推荐 |
| `football-data` skill | 赛程/xG/伤停 | 可选 |
| `sports-skills` CLI（`markets` / `news` 子命令） | 双预测市场一键匹配、结构化球队情报 | 可选 |
| **the-odds-api key** | 多家书商 h2h+spreads+totals（分析核心数据源） | **强烈推荐** |
| 飞书 bot + `lark-cli` | 每日赛果自动推送（步骤3） | 可选 |

## 配置

### 1. the-odds-api key（分析主数据源）

到 <https://the-odds-api.com> 注册（免费层 500 次/月），把 key 存到约定路径并收紧权限：

```bash
mkdir -p ~/.claude/jingcai
echo 'YOUR_API_KEY' > ~/.claude/jingcai/odds-api.key
chmod 600 ~/.claude/jingcai/odds-api.key
```

### 2. 投注台账（首次使用自建空文件）

```bash
touch ~/.claude/jingcai/ledger.md
```

台账是「唯一事实来源」，记录下单赔率/投入/状态/回款/累计统计。skill 只记录你**明确确认**的投注。

### 3.（可选）每日赛果飞书通知

`scripts/daily-jc-saiguo.sh` 通过定时任务每天抓赛果、按台账结算、推送飞书摘要。先配置环境变量：

| 环境变量 | 说明 |
|---|---|
| `FEISHU_BOT_USER_ID` | 飞书接收人 `open_id`（未设则跳过推送，仅写日志） |
| `CLAUDE_BIN` | claude 可执行路径（默认走 PATH 里的 `claude`） |
| `HTTP_PROXY_URL` | 可选，claude 访问 API 需代理时设置 |

**macOS（launchd）** 示例 —— `~/Library/LaunchAgents/com.you.jc-saiguo.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.you.jc-saiguo</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>/绝对路径/到/scripts/daily-jc-saiguo.sh</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>FEISHU_BOT_USER_ID</key><string>ou_你的openid</string>
  </dict>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>14</integer><key>Minute</key><integer>12</integer></dict>
</dict></plist>
```

加载：`launchctl load ~/Library/LaunchAgents/com.you.jc-saiguo.plist`

**Linux（cron）**：`12 14 * * * FEISHU_BOT_USER_ID=ou_xxx /bin/zsh /路径/scripts/daily-jc-saiguo.sh`

## 数据存放约定

| 路径 | 内容 |
|---|---|
| `~/.claude/jingcai/odds-api.key` | the-odds-api 密钥（`chmod 600`） |
| `~/.claude/jingcai/ledger.md` | 投注台账 |
| `~/.claude/jingcai/reviews/YYYY-MM-DD.md` | 每期复盘 |

这些都是**你本地的私有数据**，不在本仓库内（见 `.gitignore`）。

## 结构

```
.claude-plugin/
  marketplace.json     # marketplace 清单
  plugin.json          # plugin 清单
skills/jingcai-betting-loop/
  SKILL.md             # 闭环主流程
  references/
    method.md          # 五步分析管线（去水/比价/泊松/情报/出方案）
    format.md          # 方案输出格式硬性要求
scripts/
  daily-jc-saiguo.sh   # 每日赛果通知（可选自动化）
```

## License

MIT
