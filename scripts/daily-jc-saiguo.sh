#!/bin/zsh
# 每日体彩赛果飞书通知（由定时任务触发：macOS launchd 或 Linux cron）
#
# 需配置的环境变量（写进定时任务的 plist/crontab，或在此脚本顶部 source 一个 .env）：
#   FEISHU_BOT_USER_ID   飞书接收人 open_id（如 ou_xxx）。未设置则跳过飞书推送、只在日志输出摘要。
#   CLAUDE_BIN           claude 可执行文件路径（默认走 PATH 里的 `claude`）。
#   HTTP_PROXY_URL       可选。若 claude 访问 api.anthropic.com 需走代理，设为如 http://127.0.0.1:7890。
#
# 依赖：claude CLI；如需飞书推送还需 lark-cli 已登录 bot 身份。
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# 可选代理（定时任务的非交互 shell 不加载 ~/.zshrc，需在此显式设置，否则 claude 直连可能被拒）
if [ -n "$HTTP_PROXY_URL" ]; then
  export https_proxy="$HTTP_PROXY_URL" http_proxy="$HTTP_PROXY_URL" all_proxy="$HTTP_PROXY_URL"
  export no_proxy="localhost,127.0.0.1,::1,.local,feishu.cn,.feishu.cn,larksuite.com,.larksuite.com,larkoffice.com,.larkoffice.com" NO_PROXY="$no_proxy"
fi

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
LOG=~/.claude/logs/jc-saiguo-$(date +%Y%m%d).log
mkdir -p ~/.claude/logs

if [ -z "$FEISHU_BOT_USER_ID" ]; then
  echo "[$(date '+%F %T')] 提示：FEISHU_BOT_USER_ID 未设置，本次跳过飞书推送，摘要仅输出到日志。" >> "$LOG"
fi

"$CLAUDE_BIN" -p --model claude-opus-4-8 --dangerously-skip-permissions "【每日体彩赛果通知任务】执行以下步骤：
1. 用 chrome-devtools MCP（new_page → wait_for → take_snapshot）打开体彩赛果开奖页 https://www.lottery.gov.cn/jc/zqsgkj/ 抓取最近已完赛场次的赛果（比分、胜平负/让球彩果）；该页不可用时换 https://www.sporttery.cn/ltkj/ ；若 MCP 不可用则用 curl 或 WebFetch 尽力获取。
2. 读取投注台账 ~/.claude/jingcai/ledger.md（唯一事实来源），核对状态为'待开'的单各腿是否命中并计算盈亏；台账无待开单则只播报赛果。
3. 发送摘要：若环境变量 FEISHU_BOT_USER_ID 的值（下方命令中 --user-id 后）非空，用 bot 身份发飞书，必须用 --markdown（不要用 --text）：
lark-cli im +messages-send --as bot --user-id $FEISHU_BOT_USER_ID --markdown '<内容>'
若 --user-id 后为空（未配置飞书），则跳过发送，直接把下方模板内容输出到 stdout。
内容严格按以下模板（emoji+加粗节标题；每场一行；近24小时内完赛的才列；某节无内容则整节省略；不加多余客套话）：
**📊 竞彩赛果 MM-DD**
**✅ 最新完赛**
- 编号 联赛｜主队 比分 客队（半场 X:X）→ 胜平负:胜/平/负 @SP｜让球(N):让胜/平/负
**💰 投注结算**
- 单张：内容｜各腿 ✓/✗｜回款-投入=盈亏（台账无待开单时本节只写一行：台账无待开投注）
- 合计：本期 ±XX 元，累计 ±XX 元
**⏳ 待赛关注**
- 编号 联赛｜主队 vs 客队（开赛时间 MM-DD HH:mm）
4. 把结算结果（状态/回款/收盘赔率）回写 ledger.md 并重算累计统计表；同一期全部结算完时在 ~/.claude/jingcai/reviews/ 留待复盘标记。
若当天无已完赛的世界杯/国际赛场次，发一条'今日无赛果'简短消息。" >> "$LOG" 2>&1

echo "[$(date '+%F %T')] exit=$?" >> "$LOG"
