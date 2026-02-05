# 快速开始 - 操作技能题系统

## ⚡ 5分钟快速上手

### 1. 查看新增的题目
打开 `assets/operational_skills.json`：
- **op_001**: 住院天数分析 (患者风险分类)
- **op_002**: BMI区间统计 (肥胖程度分析)  
- **op_003**: 年龄区间统计 (年龄分层分析)

### 2. 运行应用
```bash
cd /Users/lixiaowei/myProject/ai_trainer_app
flutter run
```

### 3. 体验新功能
```
主屏幕 
  → 分类练习 
  → 患者数据分析 (💻代码图标)
  → 开始答题
  → 输入Python代码
  → 自动验证答案
  → 查看正确率
```

## 🎯 核心文件位置

| 文件 | 作用 |
|------|------|
| `assets/operational_skills.json` | 题库数据 |
| `lib/screens/operational_skills_screen.dart` | 答题界面 |
| `lib/nav.dart` | 路由配置 |
| `lib/services/question_bank_service.dart` | 题库服务 |
| `pubspec.yaml` | 资源配置 |

## 💡 如何添加新题目

### 第1步：编辑 `assets/operational_skills.json`
```json
{
  "id": "op_004",
  "category": "患者数据分析",  // 可以相同类别
  "title": "新题目标题",
  "question": "题目完整描述...",
  "codeTemplate": "import pandas as pd\n# 代码框架",
  "correctKeywords": ["pd.read_csv", "data['column']", "..."],
  "explanation": "答案解析说明...",
  "points": 10,
  "difficulty": "中等",
  "timeLimit": 10
}
```

### 第2步：更新版本号 (可选)
在 `lib/services/question_bank_service.dart` 中：
```dart
static const int _currentDataVersion = 7;  // 升级版本强制重新加载
```

### 第3步：运行应用
```bash
flutter run
```

**完成！** 新题目会自动加载。

## 🔍 答案验证原理

系统通过检查关键词来判断答案是否正确。

### 示例
**题目**: 统计住院天数超过7天的患者

**正确答案** (包含所有关键词):
```python
import pandas as pd
import numpy as np

data = pd.read_csv('patient_data.csv')
data['RiskLevel'] = np.where(data['DaysInHospital'] > 7, '高风险', '低风险')
risk_counts = data['RiskLevel'].value_counts()
high_risk_ratio = risk_counts['高风险'] / len(data)
```

**系统检查**:
- ✅ `pd.read_csv` 找到
- ✅ `data['RiskLevel']` 找到
- ✅ `np.where` 找到
- ✅ `DaysInHospital` 找到
- ✅ `value_counts` 找到
- ✅ `len(data)` 找到
- **结果**: ✓ 正确

## 📱 用户界面说明

### 操作技能答题界面
```
┌─────────────────────────────────┐
│ 操作技能练习                     │
├─────────────────────────────────┤
│ 第 1/3 题                        │
│ ▮▮▮░░░░░░░░░░░░░░░░░░░░░░░░░░  │  ← 进度条
│ 已完成: 0/3                      │
├─────────────────────────────────┤
│ ┌─ 第1题                      ┐  │
│ │ 通过补全并运行Python代码... │  │
│ │                            │  │
│ │ import pandas as pd        │  │ ← 代码框架
│ │ data = ____________        │  │   (灰色背景)
│ │                            │  │
│ │ 输入你的代码:              │  │
│ │ ┌──────────────────────┐  │  │
│ │ │                      │  │  │ ← 代码输入框
│ │ │ (用户输入代码)        │  │  │
│ │ └──────────────────────┘  │  │
│ └─────────────────────────────┘  │
├─────────────────────────────────┤
│ [上一题]  ✓ 正确  [下一题]      │
└─────────────────────────────────┘
```

### 完成后的统计
```
┌─────────────────────────────────┐
│  练习完成                        │
│                                 │
│  总分: 3/3                      │
│  正确率: 100.0%                 │
│                                 │
│  [返回]          [重新练习]     │
└─────────────────────────────────┘
```

## ✅ 编译和部署

### 本地编译检查
```bash
flutter analyze
# 预期结果: No compilation errors
```

### 构建Android包
```bash
flutter build apk --release
```

### 构建iOS包
```bash
flutter build ios --release
```

## 🆘 常见问题

### Q: 为什么我的代码显示错误?
**A**: 系统检查代码中是否包含所有关键词。确保包括：
- 数据读取命令
- 条件判断语句
- 统计函数
- 其他必要操作

### Q: 可以输入任意Python代码吗?
**A**: 可以，系统只检查是否包含关键词，不限制其他内容。

### Q: 如何重新加载题库?
**A**: 升级 `_currentDataVersion` 版本号，系统会自动重新加载。

### Q: 支持哪些编程语言?
**A**: 目前支持Python。后续可扩展到Java、C++等。

## 🔗 相关文件

- 📘 [完整实现指南](OPERATIONAL_SKILLS_GUIDE.md)
- 📋 [修改清单](OPERATIONAL_SKILLS_CHANGES.md)
- 📊 [项目总结](README_OPERATIONAL_SKILLS.md)

## 📞 技术支持

### 文件结构
```
ai_trainer_app/
├── assets/
│   ├── ai_trainer_bank_v2.json     (理论题库)
│   └── operational_skills.json     (操作技能题库) ← 新
├── lib/
│   ├── screens/
│   │   ├── operational_skills_screen.dart  ← 新
│   │   └── categorized_training_screen.dart (已修改)
│   ├── services/
│   │   └── question_bank_service.dart (已修改)
│   └── nav.dart (已修改)
├── pubspec.yaml (已修改)
└── OPERATIONAL_SKILLS_GUIDE.md ← 新 (详细指南)
```

### 关键类和方法

**OperationalSkillsScreen** (新)
```dart
// 加载题目
void _loadQuestions() { ... }

// 记录答案
setState(() {
  _answers[currentQuestion.id] = answer;
});

// 验证答案
bool isCorrect = currentQuestion.checkAnswer(answer);

// 提交统计
void _submitAnswers() { ... }
```

**QuestionBankService** (已修改)
```dart
// 加载操作技能题
await rootBundle.loadString('assets/operational_skills.json');

// 创建CodeQuestion
_codeQuestions = operationalDecoded.map<CodeQuestion>(...).toList();

// 获取分类题目
List<Question> getQuestionsByCategory(String categoryId);
```

---

**状态**: ✅ 生产就绪  
**最后更新**: 2026年1月13日
