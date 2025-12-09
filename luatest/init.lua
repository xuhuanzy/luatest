-- luatest 主模块
-- 导出所有公共 API

local runner_module = require("luatest.runner")

return {
    -- 测试定义 API
    describe = runner_module.describe,
    test = runner_module.test,
    it = runner_module.it,

    -- 生命周期钩子
    beforeAll = runner_module.beforeAll,
    afterAll = runner_module.afterAll,
    beforeEach = runner_module.beforeEach,
    afterEach = runner_module.afterEach,

    -- 收集和执行
    collectTests = runner_module.collectTests,
    runFiles = runner_module.runFiles,
}
