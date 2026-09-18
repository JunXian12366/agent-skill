---
name: pmp-java-feature
description: "在 PMP 租赁通知服务中实现用户明确要求的 Java/Spring 功能或代码修改。不适用于 C# 转 Java（使用 pmp-java-convert-from-csharp）、仅分析的问题、未获修复授权的诊断、只读审查或仅测试任务。"
---

# PMP Java 功能开发

如果可以访问 `..\..\copilot-instructions.md`，请遵循其中的共享约束；此处引用不会自动激活这些约束。

## 操作步骤
1. 确认请求明确表达了实现功能或修改代码的意图。提取预期行为、受影响的接口契约和验收标准；仅澄清会实质性影响实现的歧义。
2. 检查相关 controller、service 接口及实现、Feign 契约和 model 类型。沿用现有模式，不要扫描整个仓库。
3. 检查相关测试，建立安全的验证基线。在受影响的各层完成最小但完整的修改；使用现有测试工具补充有针对性的回归测试。
4. 修改后运行相关且安全的检查，并检查差异中是否混入无关改动。

## 任务边界
- 不要把解释说明类请求变成实现任务。
- 不要仅因存在某项依赖就引入持久化或消息架构。
- 保持公共接口契约不变，除非所请求的行为确实需要变更且已获得明确授权。
- 在 `pmp-data-lease` 中新增/修改仓储查询时，禁止使用 `@Query` 的 HQL/JPQL/原生 SQL 字符串（含 `join fetch`）；一律通过 `XxxRepositoryCustom`/`XxxRepositoryImpl` + `CriteriaBuilder` 实现，详见共享约束文件。
- 涉及"当前日期"默认值的设置（如查询参数缺省时补默认报表日期等）一律放在 `pmp-service-lease` 层完成，不要放在 `pmp-channel-lease` 层；且必须通过 `com.spl.pmp.service.lease.utils.DateUtils.getCurrentLocalDate()` 获取当前日期，禁止直接使用 `LocalDate.now()`。
- 编写/修改代码时不要自动添加注释或 `@Schema(description = ...)` 等接口文档注解；仅在用户明确要求时才添加。
- 遵守 SonarQube 常见规则：不要使用 `record` 等受限标识符作为变量/参数名（S6213）；日期字面量优先使用 `java.time.Month` 等枚举常量而非裸整数（S8694）。
- 代码中不要使用带完整包名的内联类引用（如 `com.spl.pmp.service.lease.report.utils.AsposeExcelUtils.CellStyleConfig`）；应通过 `import` 引入类型后使用简名（嵌套类沿用项目既有写法，如 `import ...AsposeExcelUtils;` 后使用 `AsposeExcelUtils.CellStyleConfig`）。
- 在 Feign 客户端接口（如 `LeaseDataClient`/`LeaseServiceClient`/`LeaseReportServiceClient`）中新增方法时，一律追加到接口末尾（最后一个已有方法之后、右花括号之前），不要插入到已有方法中间。

## 证据与完成标准
报告修改的文件、实现的行为、对接口契约的影响，以及具体检查和结果。说明设计决策时引用源码位置。完成任务需覆盖验收标准并通过相关检查；否则，必须明确说明哪些内容尚未验证及其原因。绝不能将受阻的验证描述为成功。
