# 分类练习页面修改说明

## 修改概述

对分类练习页面进行了结构优化，实现了**按能力模块分组展示**的新设计，提升了页面的清晰度和学习引导性。

## 主要变更

### 1. **一级分类：理论知识 vs 操作技能**

#### 理论知识模块
- **模块标题**：「理论知识」
- **描述文案**：「通过习题巩固知识，掌握理论基础」
- **视觉标识**：绿色系主题（🎓 学校图标）
  - 背景色：`#E8F5E9`（浅绿）
  - 强调色：`#2E7D32`（深绿）
- **包含内容**：
  - 判断题（True/False）
  - 单选题（Single Choice）
  - 多选题（Multiple Choice）

#### 操作技能模块
- **模块标题**：「操作技能」
- **描述文案**：「通过实践任务锻炼动手能力」
- **视觉标识**：蓝色系主题（💻 代码图标）
  - 背景色：`#E3F2FD`（浅蓝）
  - 强调色：`#1565C0`（深蓝）
- **包含内容**：
  - 患者数据分析
  - 传感器数据分析
  - 其他代码/数据处理任务

### 2. **视觉与语义强化**

#### 分组标题栏设计
- 每个模块顶部显示带彩色背景的标题栏
- 包含模块图标、标题、描述文案
- 颜色区分清晰，帮助用户快速识别学习类型

#### 分类卡片优化
- **左侧边框**：4像素彩色边框，用于区分卡片类型
  - 理论知识：紫红色（`#C2185B`）
  - 操作技能：深紫色（`#7B1FA2`）
- **类型标签**：卡片右上角显示标签
  - 理论知识：「刷题」标签
  - 操作技能：「实践」标签
- **图标样式**：背景色与模块颜色关联，视觉一致性强

### 3. **代码结构优化**

#### 新增 `_ModuleSection` 组件
- 职责：管理模块分组展示
- 参数：
  - `title`：模块标题
  - `description`：模块描述
  - `icon`：模块图标
  - `backgroundColor`：背景色
  - `iconColor`：强调色
  - `children`：分类卡片列表

#### 优化 `_CategoryCard` 组件
- 添加题型标签显示（「刷题」/「实践」）
- 优化颜色方案，动态适配模块类型
- 改进间距和排版，提升视觉层次

#### 主屏幕逻辑
- 自动分组：根据题目的 `section` 字段分类
  - `QuestionSection.theoretical` → 理论知识模块
  - `QuestionSection.operational` → 操作技能模块
- 条件渲染：仅显示有内容的模块

## 用户体验提升

| 方面 | 改进点 |
|------|-------|
| **理解度** | 用户一眼可分辨题型与技能的区别 |
| **导航性** | 按模块分组，逻辑清晰，减少查找成本 |
| **学习指导** | 每个模块配有清晰的文案引导 |
| **视觉美感** | 颜色系统统一，界面整洁专业 |

## 技术细节

### 数据流向
```
QuestionBankService.categories
  ↓
按 QuestionSection 分类
  ├─ theoretical → theoreticalCategories
  └─ operational → operationalCategories
  ↓
_ModuleSection (2个实例)
  ├─ 理论知识 (_ModuleSection + 多个 _CategoryCard)
  └─ 操作技能 (_ModuleSection + 多个 _CategoryCard)
```

### 颜色系统

**理论知识模块**
- 背景：`#E8F5E9`
- 强调：`#2E7D32`
- 卡片边框：`#C2185B`（紫红）

**操作技能模块**
- 背景：`#E3F2FD`
- 强调：`#1565C0`
- 卡片边框：`#7B1FA2`（深紫）

### 依赖的枚举
```dart
enum QuestionSection { theoretical, operational }
enum QuestionType { trueFalse, singleChoice, multipleChoice, codeCompletion }
```

## 文件修改位置

**文件**：[lib/screens/categorized_training_screen.dart](lib/screens/categorized_training_screen.dart)

- `CategorizedTrainingScreen`：主屏幕组件，新增分组逻辑
- `_ModuleSection`：新增组件，用于模块分组展示
- `_CategoryCard`：优化组件，添加题型标签和颜色适配

## 测试建议

1. **验证分组**：确保所有题目正确分配到两个模块
2. **颜色验证**：检查两个模块的颜色差异是否清晰
3. **响应式**：在不同屏幕尺寸上检查布局
4. **交互**：点击卡片，验证路由导航正确（`/category` vs `/operational-skills`）

## 后续优化空间

1. 可为理论知识模块按题型（判断/单选/多选）进行二级细分
2. 可添加进度指示器（已做/未做题目数）
3. 可添加模块完成度进度条
4. 可在模块标题栏添加"查看全部"快捷链接
