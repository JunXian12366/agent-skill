---
applyTo: '**/*.java'
---

# PMP 多仓库分层职责规则

- `pmp-data-lease`（以及其他 `pmp-data-*` 数据服务）的 Repository/RepositoryImpl 只做贴近原始行的纯数据查询，不做业务处理、数据整理或展示逻辑；业务处理一律放在对应的 `pmp-service-lease`（或其他 `pmp-service-*`）业务服务的 Service 层中完成。
- 多语言字段的选择/过滤（例如按请求的 `lang` 参数在 Code/CodeDescription 或实体的 Lang1/Lang2/Lang3/Lang4 等多语言列中挑选展示文本）不要放在 `pmp-data-lease` 或 `pmp-service-lease` 中处理；这类"最终展示语言筛选"逻辑应放在报表展示层（如 `pmp-service-lease-report`）根据报表请求的语言参数统一筛选。`pmp-data-lease`/`pmp-service-lease` 只需把各语言的原始字段都如实返回（或返回原始 code 值），不要提前按语言收窄。
- `pmp-data-lease` 的 Repository/RepositoryImpl 不要为了获取 Code 的描述文本而关联 `CodeEntity`/`CodeDescriptionEntity` 做业务性的 code 查询与整理（例如为了拿到某个业务字典的展示文案而 JOIN 并按语言过滤）；应只返回原始 code 值，由上层（业务服务或报表服务）负责查询/转换 code 对应的描述文本。
- `pmp-data-lease` 的 Repository/RepositoryImpl 不要基于 `SystemParameter` 等配置类实体的业务 code key 查询后，在数据层内直接解析/拆分/过滤（例如按逗号分隔字符串解析出排除列表、根据配置值做业务判断等）；应只提供按 code 查询 `SystemParameter` 原始值的通用查询方法，具体的业务解析与应用放在service层，如 `pmp-service-lease` 的 Service 层完成。
- 数据层查询（Repository/RepositoryImpl）中不要出现静态常量定义；字段路径、code 值等常量应定义在对应的实体（Entity）类中。
