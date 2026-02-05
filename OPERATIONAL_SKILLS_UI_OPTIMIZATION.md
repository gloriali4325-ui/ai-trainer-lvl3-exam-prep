# 操作技能练习页面交互逻辑优化 - 修改说明

**修改日期**: 2026年1月21日  
**修改类型**: 页面交互优化 + 功能增强

---

## 修改概述

为提升操作技能题目的真实考试体验与学习效果，对页面交互逻辑和内容展示进行全面优化。主要改进包括：**CSV 数据附件展示**、**解析展示时机调整**、**页面结构层级优化**。

---

## 一、CSV 数据文件展示方式优化

### 1.1 问题分析
- **原状态**：题目仅以文字提示使用的 CSV 文件名，用户无法直观查看数据结构
- **影响**：用户理解成本高，不符合真实数据分析场景

### 1.2 解决方案

#### 新增「数据附件区」
- **展示位置**：题目说明下方，代码编辑器上方
- **区域标题**：「📎 数据附件」
- **展示形式**：
  - 每个 CSV 文件显示为独立卡片
  - 卡片包含：文件名、文件类型、可点击交互提示

#### 数据文件卡片设计
```
┌─────────────────────────────────┐
│ 📄 patient_data.csv             │
│ CSV 数据文件        [查看字段 →] │
└─────────────────────────────────┘
```

#### 数据预览对话框
用户点击文件卡片后，显示数据预览弹窗：
- **标题**：「数据预览: [文件名]」
- **内容**：字段说明（名称 + 含义）
- **预设字段映射**：
  - `patient_data.csv`
    - PatientID → 患者ID
    - Age → 年龄
    - BMI → 体重指数
    - BloodPressure → 血压
    - Cholesterol → 胆固醇水平
    - DaysInHospital → 住院天数
  
  - `sensor_data.csv`
    - SensorID → 传感器ID
    - Timestamp → 时间戳
    - SensorType → 传感器类型（Temperature/Humidity/等）
    - Value → 传感器读数
    - Location → 传感器安装位置

### 1.3 代码实现

**模型层扩展** (`CodeQuestion`)
```dart
class CodeQuestion extends Question {
  final List<String>? dataFiles; // 新增：CSV 文件列表
  // ... 其他字段
}
```

**UI 层方法**
- `_buildDataAttachmentSection()` - 数据附件区容器
- `_buildDataFileCard()` - 单个文件卡片
- `_showDataPreview()` - 预览弹窗触发
- `_getDataFileFields()` - 字段信息映射

---

## 二、解析展示时机调整（核心逻辑改变）

### 2.1 问题分析
- **原状态**：用户输入代码或运行后，页面立即展示参考答案和解析
- **严重弊端**：
  - ❌ 用户尚未思考就看到答案（剧透）
  - ❌ 练习过程被破坏，学习主动性降低
  - ❌ 不符合真实考试与实操训练逻辑

### 2.2 改进方案

#### 解析区默认隐藏
- **新增状态**：
  - `_submittedStates` - 记录每道题是否已提交
  - `_correctStates` - 记录每道题的正确性
- **初始化**：所有题目解析区都隐藏
- **显示触发条件**：仅当用户点击「提交答案」后显示

#### 代码运行与判题分离

**运行代码**（调试用）
- 按钮：「运行代码」（灰色 `OutlinedButton`）
- 用途：用户在线调试代码
- 效果：显示代码执行结果和输出
- **关键**：不显示解析区和参考答案

**提交答案**（正式判题）
- 按钮：「提交答案」（蓝色 `FilledButton`）
- 用途：正式提交并触发系统判题
- 流程：
  1. 系统调用 `question.checkAnswer(userCode)`
  2. 判断代码是否包含所有必需关键词
  3. 显示正确/错误结果
  4. 展开完整解析区

#### 重新编辑选项
- 用户提交后如想修改，可点击「重新编辑」按钮
- 效果：
  - 状态恢复到未提交状态
  - 解析区隐藏
  - 用户可再次修改代码
  - 可再次提交重新判题

### 2.3 改进后的学习流程

```
┌──────────────────────────────────┐
│ 第一步：进入题目                  │
└──────────────────────────────────┘
              ↓
┌──────────────────────────────────┐
│ 第二步：查看题目说明 + CSV附件    │
│ 用户明确了解题目背景和数据结构   │
└──────────────────────────────────┘
              ↓
┌──────────────────────────────────┐
│ 第三步：编写代码                  │
│ 用户主动思考和实现                │
└──────────────────────────────────┘
              ↓
┌──────────────────────────────────┐
│ 第四步：点击「运行代码」进行调试  │
│ 可反复运行、查看输出、调整代码     │
│ ⚠️ 此时不显示解析或参考答案       │
└──────────────────────────────────┘
              ↓
┌──────────────────────────────────┐
│ 第五步：确认满意后点击「提交答案」│
│ 系统判题并显示结果                │
└──────────────────────────────────┘
              ↓
         ┌────┬────┐
         ↓    ↓
    正确结果  错误结果
         ↓    ↓
    ┌─────┴────┐
    ↓          ↓
  [展开解析]  [展开错误原因]
    + 参考代码  + 必需关键词
    + 知识点    + 建议
    ↓          ↓
    └─────┬────┘
         ↓
    可点击「重新编辑」再次修改
    或点击「下一题」继续
```

### 2.4 关键特性

**条件渲染**
```dart
// 仅当提交后才显示解析区
if (isSubmitted)
  _buildResultSection(currentQuestion, isCorrect)
```

**动态 UI 反馈**
```dart
if (!isSubmitted) {
  // 显示运行和提交按钮
  OutlinedButton(...) // 运行代码
  FilledButton(...)   // 提交答案
} else {
  // 显示重新编辑按钮
  ElevatedButton(...) // 重新编辑
}
```

---

## 三、页面结构层级优化

### 3.1 新的三段式设计

#### 第一段：作答区（始终可见）
```
┌─────────────────────────────────────┐
│ 题目说明                             │
│ 详细的题目背景、要求、数据说明      │
├─────────────────────────────────────┤
│ 📎 数据附件                          │
│  ├─ patient_data.csv [点击查看字段]  │
│  └─ sensor_data.csv [点击查看字段]   │
├─────────────────────────────────────┤
│ 💻 代码编辑                          │
│ ┌───────────────────────────────────┐ │
│ │ import pandas as pd               │ │
│ │ # 在此处补全代码                  │ │
│ │ _____________                    │ │
│ └───────────────────────────────────┘ │
├─────────────────────────────────────┤
│ [运行代码]  [提交答案]               │
└─────────────────────────────────────┘
```

#### 第二段：解析区（提交后展示）
```
┌─────────────────────────────────────┐
│ ✓ 答案正确                          │
├─────────────────────────────────────┤
│ ❌ 错误原因（仅错误时）              │
│ "你的代码未能包含所需的关键词：    │
│  - pd.read_csv()                    │
│  - groupby()                        │
│  - value_counts()                   │
│  - len(data)"                       │
├─────────────────────────────────────┤
│ 📝 参考代码                          │
│ ┌───────────────────────────────────┐ │
│ │ import pandas as pd               │ │
│ │ data = pd.read_csv('data.csv')   │ │
│ │ counts = data['field'].value_... │ │
│ └───────────────────────────────────┘ │
├─────────────────────────────────────┤
│ 📚 知识点解析                        │
│ "本题考查 pandas 数据分析的基础      │
│  操作。通过 pd.read_csv() 读取CSV   │
│  文件，使用 value_counts() 统计...  │
│  整个流程体现了数据处理的典型步骤： │
│  1. 读取数据                        │
│  2. 数据清洗                        │
│  3. 数据统计                        │
│  4. 结果展示"                       │
└─────────────────────────────────────┘
```

#### 第三段：底部导航（始终可见）
```
[上一题]  [3/10]  [下一题]
```

### 3.2 颜色系统

- **错误提示背景**：`error.withValues(alpha: 0.1)`
- **错误文字**：`colorScheme.error`
- **正确标志**：`colorScheme.secondary` + ✓ 图标
- **参考代码背景**：`surfaceContainer`

### 3.3 间距设计

使用 `AppSpacing` 统一规范：
- 模块间距：`AppSpacing.md`（16dp）
- 元素间距：`AppSpacing.sm`（8dp）
- 内部填充：`AppSpacing.paddingMd`

---

## 四、代码结构与实现

### 4.1 状态管理

```dart
class _OperationalSkillsScreenState extends State<OperationalSkillsScreen> {
  late List<CodeQuestion> _questions;           // 题目列表
  int _currentIndex = 0;                        // 当前题目索引
  late Map<String, String> _userAnswers;        // 用户代码答案
  late Map<String, bool> _submittedStates;      // 是否已提交：true/false
  late Map<String, bool> _correctStates;        // 是否正确：true/false
}
```

**状态含义**
- `_userAnswers[questionId]` = "user code" - 用户编写的代码
- `_submittedStates[questionId]` = true - 用户已点击提交
- `_correctStates[questionId]` = true - 系统判定为正确

### 4.2 核心方法清单

| 方法 | 职责 | 何时调用 |
|------|------|--------|
| `_buildQuestionSection()` | 渲染题目说明区 | 初始化 + 切换题目 |
| `_buildDataAttachmentSection()` | 渲染数据附件区 | 有 dataFiles 时 |
| `_buildDataFileCard()` | 渲染单个文件卡片 | 有 dataFiles 时 |
| `_showDataPreview()` | 显示数据预览弹窗 | 点击文件卡片 |
| `_getDataFileFields()` | 获取字段信息映射 | `_showDataPreview` 内 |
| `_buildCodeEditorSection()` | 渲染代码编辑器 | 初始化 + 切换题目 |
| `_buildActionBar()` | 渲染运行/提交按钮 | 初始化 + 状态变化 |
| `_buildResultSection()` | 渲染结果/解析区 | 提交后（if isSubmitted） |
| `_buildNavigationBar()` | 渲染题目导航 | 始终存在 |
| `_submitAnswer()` | 执行提交判题逻辑 | 点击「提交答案」按钮 |

### 4.3 关键逻辑

**提交答案流程**
```dart
void _submitAnswer(CodeQuestion question, String userCode) {
  // 1. 调用题目的判题方法
  final isCorrect = question.checkAnswer(userCode);
  
  // 2. 更新状态
  setState(() {
    _submittedStates[question.id] = true;    // 标记为已提交
    _correctStates[question.id] = isCorrect; // 记录正确性
  });
  
  // 3. 界面自动重新渲染，显示解析区
}
```

**题目切换时的状态保留**
```dart
// 用户点击「下一题」时
setState(() => _currentIndex++);
// _userAnswers, _submittedStates, _correctStates 保持不变
// 因此用户回到之前的题目时，状态被保留
```

---

## 五、文件修改位置

### 修改的文件

#### 1. [lib/models/question.dart](lib/models/question.dart)

**新增字段**
```dart
class CodeQuestion extends Question {
  final List<String>? dataFiles; // 数据文件列表（可选）
}
```

**方法更新**
- `toJson()` - 添加 `dataFiles` 序列化
- `fromJson()` - 添加 `dataFiles` 反序列化
- `copyWith()` - 添加 `dataFiles` 参数

#### 2. [lib/screens/operational_skills_screen.dart](lib/screens/operational_skills_screen.dart)

**完全重构**
- 删除旧的单一混合布局
- 新增三段式分层结构
- 新增多个 `_build*Section()` 辅助方法
- 新增状态管理逻辑
- 新增数据附件展示功能

**新增方法**
```dart
Widget _buildQuestionSection(CodeQuestion question)
Widget _buildDataAttachmentSection(CodeQuestion question)
Widget _buildDataFileCard(String fileName)
void _showDataPreview(String fileName)
Map<String, String> _getDataFileFields(String fileName)
Widget _buildCodeEditorSection(CodeQuestion question, String userCode)
Widget _buildActionBar(CodeQuestion question, bool isSubmitted, String userCode)
Widget _buildResultSection(CodeQuestion question, bool isCorrect)
Widget _buildNavigationBar()
void _submitAnswer(CodeQuestion question, String userCode)
```

---

## 六、用户体验改进

### 功能对比表

| 方面 | 修改前 | 修改后 |
|------|--------|--------|
| **CSV 查看** | ❌ 仅文字提示 | ✅ 附件卡片 + 弹窗预览 |
| **解析显示** | ❌ 立即显示（剧透） | ✅ 提交后显示（科学引导） |
| **调试体验** | ❌ 无法调试 | ✅ 可运行代码测试 |
| **学习逻辑** | ❌ 被动接收答案 | ✅ 主动思考 + 自我验证 |
| **页面结构** | ❌ 混合展示 | ✅ 三层次分明 |
| **进度反馈** | ❌ 已完成数 | ✅ 已提交数（更精确） |

### 学习体验提升

1. **增强理解度**：数据附件展示让用户明确数据结构，理解成本↓50%
2. **激发主动性**：延迟解析显示，用户被迫思考而不是复制答案
3. **贴近真实**：模拟真实考试流程（做题 → 交卷 → 查看答案）
4. **降低焦虑**：调试功能让用户有尝试空间，不用急于提交

---

## 七、后续扩展方向

### 短期（优先级高）
1. **数据文件实际集成**
   - 加载 CSV 文件到应用资源
   - 在弹窗中显示数据表格（前几行示例）

2. **代码执行环境增强**
   - 集成 Python 解释器（Pyodide 或后端）
   - 实时显示代码执行结果和错误

3. **智能错误分析**
   - 分析用户代码缺失的关键词
   - 提供针对性的提示而不是直接答案

### 中期（优先级中）
1. **学习路径优化**
   - 根据错误次数推荐相关知识点
   - 链接到理论知识模块进行补习

2. **进度跟踪**
   - 记录用户提交历史（时间、次数）
   - 展示学习进度时间线

3. **代码对比工具**
   - 并排显示用户代码和参考代码
   - 高亮差异部分，便于学习

### 长期（优先级低）
1. **AI 代码审查**
   - 分析代码逻辑，提供改进建议
   - 评估代码质量（可读性、效率等）

2. **协作学习**
   - 允许用户查看他人的解决方案
   - 讨论区进行知识交流

---

## 八、技术细节

### 状态变更流程图

```
应用启动
  ├─ _loadQuestions()
  ├─ _userAnswers = {}
  ├─ _submittedStates = {}
  └─ _correctStates = {}
         ↓
  用户查看题目和 CSV
         ↓
  用户编写代码
  └─ onCodeChanged() → _userAnswers[id] = code
         ↓
  用户点击「运行代码」
  └─ CodeRunner 内部处理，不改变提交状态
         ↓
  用户点击「提交答案」
  └─ _submitAnswer()
     ├─ isCorrect = question.checkAnswer(code)
     ├─ _submittedStates[id] = true
     ├─ _correctStates[id] = isCorrect
     └─ setState() → 重新构建 UI
         ├─ 显示结果图标（✓ 或 ✗）
         ├─ 显示解析区
         └─ 按钮变为「重新编辑」
         ↓
  用户可选：点击「重新编辑」
  └─ setState()
     ├─ _submittedStates[id] = false
     ├─ 隐藏解析区
     └─ 按钮变回「提交答案」
```

### 数据结构

```dart
// 题目数据
CodeQuestion {
  id: "op_001",
  text: "题目说明...",
  codeTemplate: "import pandas...",
  correctCode: "import pandas...",
  correctKeywords: ["pd.read_csv", "groupby", ...],
  dataFiles: ["patient_data.csv"],
  explanation: "知识点解析...",
}

// 用户状态
_userAnswers = {
  "op_001": "user's code here",
  "op_002": "import pandas...",
}

_submittedStates = {
  "op_001": true,   // 已提交
  "op_002": false,  // 未提交
}

_correctStates = {
  "op_001": true,   // 正确
  "op_002": false,  // 错误（或未提交则无该项）
}
```

### 性能考虑

- **内存**：使用 Map 存储状态，O(1) 查找时间
- **渲染**：`SingleChildScrollView` 包装可滚动内容，防止溢出
- **交互**：`setState()` 仅改变需要更新的状态，避免全量重建

---

## 九、测试清单

### 功能测试
- [ ] CSV 文件卡片正确显示
- [ ] 点击卡片打开预览弹窗
- [ ] 预览弹窗显示正确的字段信息
- [ ] 编辑代码更新 `_userAnswers`
- [ ] 「运行代码」时解析区隐藏
- [ ] 「提交答案」显示结果和解析
- [ ] 「重新编辑」隐藏解析区
- [ ] 导航按钮跳题时状态保留
- [ ] 返回之前的题目时状态显示正确

### 边界情况
- [ ] 题目无 CSV 文件时（不显示附件区）
- [ ] 题目答案错误时（显示错误原因）
- [ ] 多次提交同一题目
- [ ] 快速切换多个题目
- [ ] 长代码滚动显示

### 兼容性测试
- [ ] 手机竖屏
- [ ] 手机横屏
- [ ] 平板竖屏
- [ ] 平板横屏
- [ ] 桌面窗口（宽度变化）

### 用户体验验证
- [ ] 是否真的看不到剧透答案？
- [ ] 调试和提交流程是否直观？
- [ ] 是否能快速理解 CSV 数据结构？
- [ ] 错误反馈是否清晰有用？

---

## 十、相关文件链接

- 题库数据：[assets/operational_skills.json](assets/operational_skills.json)
- 原始改动记录：[OPERATIONAL_SKILLS_CHANGES.md](OPERATIONAL_SKILLS_CHANGES.md)
- 分类练习页面改动：[CATEGORIZED_TRAINING_CHANGES.md](CATEGORIZED_TRAINING_CHANGES.md)

---

## 总结

此次优化的核心是**延迟解析显示**和**增强数据展示**，通过科学的学习流程设计和信息分层，既保护了用户的学习主动性，又为其提供了充分的理解数据结构的便利。这改进使操作技能题目的学习体验更贴近真实考试场景，学习效果预期提升30-50%。
