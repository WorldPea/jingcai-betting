# 体彩竞彩分析管线（极简版）

> 本文件是 `jingcai-betting-loop` skill 的内置分析方法论。开工分析时读全文、按五步建 TodoWrite 逐项执行。文中金额/路径为示例，按需调整。**本精简版聚焦"分析出方案"，不含资金管理与台账。**

## 执行步骤（按序）

### 第1步 拿体彩赔率 — webapi JSON 接口首选

curl 直取 JSON（无需渲染、省 token）：

```bash
curl -H "User-Agent: Mozilla/5.0" -H "Referer: https://m.sporttery.cn/" \
  -H "Accept: application/json, text/plain, */*" -H "Origin: https://m.sporttery.cn" \
  --noproxy '*' \
  "https://webapi.sporttery.cn/gateway/jc/football/getMatchCalculatorV1.qry?poolCode=hhgg&channel=c"
```

`poolCode=hhgg`（混合过关）一次返回全部玩法。结构：`value.matchInfoList[]` 按 `matchDateStr` 分段（=北京日期）；玩法字段 `had{h,d,a}`=胜平负、`hhad{goalLine,h,d,a}`=让球、比分/总进球/半全场同理。**停售时段** hhgg 仅返 `vtoolsConfig`，改用单玩法池 `had/hhad/crs` **分别请求**（结构为 `subMatchList[]`、字段 `homeTeamAbbName/awayTeamAbbName`，需按 `matchNumStr` 合并）。偶发空响应重试 2-3 次。

- 后备：Chrome 渲染 `m.sporttery.cn/mjc/jsq/` 各玩法页（比分 `zqbf/`、总进球 `zqzjq/` 等）
- 用户发截图：直接读图，底部被截断的冷门比分用 ~700 占位（影响 <0.5%）
- ⚠️ **编号≠北京日期**：场次"周X00N"的周X是赛事编号日（约等于比赛地当地日），北京开赛=编号日+1 凌晨/上午；报场次**必带北京时间开赛时刻**

### 第2步 去水算公平概率

`1/odds` 求隐含 → 除以总隐含 → 公平概率。**组合 EV 必须直接代入去水输出数组，禁止手抄中间值。**

- 美式转换：负 odds → `1+100/|odds|`；正 odds → `1+odds/100`
- **水位档位**：胜平负/让球 ~12.9%；总进球/半全场 ~25.4%；比分 ~40%。只用低水盘做腿
- **损耗规律**：低水盘每加一腿期望回收 ×0.886。二串 −21.5%、三串 −30%、四串 −38%。**二串低水盘是性价比上限**

### 第3步 国际比价 + 泊松反推 找错价

**a) 多家盘口共识（主通路）**——the-odds-api `regions=eu,uk,us` 一次约 48 家，python 算各家去水概率的**均值 + 离散度 σ + 让球/大小线分布**（σ 小=市场确信、σ 大=不确定须标注、某家偏离均值=潜在错价线索）：

```bash
KEY=$(grep -o '[0-9a-f]\{32\}' ~/.claude/jingcai/odds-api.key)
curl "https://api.the-odds-api.com/v4/sports/soccer_fifa_world_cup/odds/?apiKey=$KEY&regions=eu,uk,us&markets=h2h,spreads,totals&oddsFormat=decimal"
```

（免费 500/月；耗额=markets×regions。全梯队 `alternate_totals/spreads` 须走单赛事端点 `/events/{id}/odds`。）第二/三独立源 Kalshi+Polymarket（群体真金）：`sports-skills markets match_markets --sport=worldcup`。

**b) 双方法去水保守取值**：同组国际赔率分别跑按比例法和 power 法（二分求 k 使 Σp^k=1），**EV 取两法较低者**（防冷门偏差陷阱）。

**c) 时点对齐**：体彩用固定奖金页实时价，与国际报价时间差 ≤1h。**临场盘几分钟就移动，每次出方案重拉最新盘**，旧 λ 仅远期未变盘时复用且须声明。

**d) 比分级泊松反推交叉验证**（找盘口间不自洽，**非正 EV 来源**）：
- 输入用真金基准让球主盘线 L_让 与大小主盘线 L_大（主盘=两边赔率最接近 1.9 那条；**禁用体彩高水赔率**）
- 反推：H=(L_大+L_让)/2、A=(L_大−L_让)/2（让球以"主队让为正"取号）
- 泊松还原 `P(h,a)=Pois(H,h)·Pois(A,a)`，聚合回 1X2/让球/总进球/比分
- Dixon-Coles τ 修正低分平局（抬高 0:0/1:1、压低 1:0/0:1，ρ≈0.10）
- ⚠️ **铁律**：让球/大小一律用**国际同线去水**算 EV（可靠）；仅跨线才动泊松，且**只信方向不信绝对值**（split/整球让球泊松常吐假正 EV）
- ⚠️ 冷门/低频比分的绝对正 EV 几乎都是模型噪声 + favourite-longshot bias，**只信同方向比分间的相对排序**，绝不照搬绝对 EV 追冷门比分
- **λ 可信度降级链**：高（≥2 源 Δ<0.2）/ 中（1 源直接亚盘 或 2 源三向拟合）/ 低（单源）。低可信场次标注"λ 仅供参考"、降权或跳过

### 第4步 情报校验（四来源）

- **a) 官方"析"页**（Chrome 渲染 `sporttery.cn/jc/zqdz/index.html?showType=2&mid=<mid>`）：伤停一览、未来赛事（轮换/动机）、近况含半场比分
- **b) 官方"固定奖金"页**（`showType=3`）：赔率变动时间序列＝资金流向（某方向持续上调=被看衰）；取最后一行做实时核对
- **c) WebSearch** `"队名 team news predicted lineup injuries"`：预测首发 + Opta 概率
- **d) xG 攻防强度交叉**（Opta/Understat）：与市场反推 λ 背离即错价/情报点；仅作交叉验证、不替代市场 λ

⚠️ **公开情报已被盘口定价，不据此逆市场下注**；正确用法只有三处：(a) 比分选号判断、(b) 首发公布后 1-2h 体彩滞后窗口、(c) 轮换/稳腿风险标注。小组赛末轮额外查**出线形势/动机**（已出线大轮换、形势危急搏命、已淘汰摆烂）。

### 第5步 出方案

按 `references/format.md`：整十金额、命中概率列、结果分布表、稳健/平衡/博大梯度。**末尾另附"比分推荐"独立板块**（每场主推1+备选2，每注 50 元）。比分推荐选号优先用第 3 步 d) 的泊松反推分布（国际盘真金 λ）排序，优于单看体彩 crs 去水。

## 关键纪律（出方案前自检）

1. **数据源优先**：用户给了低水波胆 → 直接去水用之，别用模型反推
2. **比分主推自洽**：方向措辞 vs 主推比分一致（说大胜给大比分）；禁用泊松/DC 峰值当主推。**强攻击群强队打弱旅→大比分（2:0）；防守战/双弱/减员→小比分（1:0/1:1）；大热 vs 摆大巴→升 1:1/0:0 为联合主推/对冲**
3. **零封对冲**：押单方零封 0:X 必配"弱队进1球"对冲号（1:3/1:2），否则不押该腿
4. **多源验证**：情报 ≥2 个独立信源（同源转载算 1 个）；严禁据未验证公开情报逆市场调概率
5. **市场分散剔场**：波胆去水前 4 档有主导=方向干净做基底；挤在 ≤2pp 内无主导=方向乱踢出只观察。**判断来回改＝这场没把握，听市场（剔除）**
6. **比分串大概率全损是常态**：以小搏大买的是 ~10% 的希望，别因一轮全损推翻方法、别因偶中高估预测力

## 损耗控制三原则

①无票跳过（负 EV 游戏里不下注就是最优解）＞②能单关不串（省一半损耗，查赛程总表 `u-dan`=可单关）＞③只用低水盘做腿。

- **让球语义**：让 N 负 = 让球后主队输（净胜 ≤ N−1 或不胜）
- 境外低水位平台（Pinnacle 等）**仅作比价基准**，大陆经其投注违法，不推荐不协助

## 方法论定位

本管线＝**市场反推 λ(supremacy/total) → DC 比分分布**＝用最准输入（市场赔率）喂经典比分模型。⚠️ **天花板**：所有方法对"具体比分"预测力极有限（最可能比分也才 ~15% 命中），方法论先进只改善胜平负/让球/大小的**区间**精度，救不了押单一比分。**操作含义：主盘信市场赔率、比分当乐透。**

## 工具通路（实测结论）

| 通路 | 用途 | 状态 |
|---|---|---|
| webapi.sporttery.cn JSON | 体彩实时赔率 | ✅ 首选，curl 直连需带 UA/Referer/Accept/Origin 头 + `--noproxy '*'` |
| the-odds-api（需 key） | 多家书商 h2h+spreads+totals 共识 + 反推 λ | ✅ 主通路，`regions=eu,uk,us` 约 48 家，免费 500/月 |
| chrome-devtools MCP | 体彩页后备、固定奖金页/情报页 | ✅ 用 `evaluate_script` 抽关键数字省 token，勿整页 take_snapshot |
| WebSearch / WebFetch | 国际赔率、伤停、首发、Opta | ✅ 免费层 λ 数据源（搜"队名 asian handicap over under odds"） |
| markets CLI | Kalshi+Polymarket 一键匹配 | ✅ `sports-skills markets match_markets --sport=worldcup` |
| news CLI | 结构化球队情报 | ✅ `sports-skills news fetch_items --query="队名 lineup injury"` |
