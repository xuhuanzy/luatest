---@namespace Luatest

---@alias PartialFunction<T> { [P in keyof T]: P extends "__index" and nil or T[P] extends function and T[P]? or T[P]; }

---@class Inverse<T>
---@field not_ T 取反断言

---@alias Tester fun(self: TesterContext, a: any, b: any, customTesters: Tester[]): boolean?

---@alias EqualsFunction fun(a: any, b: any, customTesters?: Tester[], strictCheck?: boolean): boolean

---@class TesterContext
---@field equals EqualsFunction

---@class ExpectationResult
---@field pass boolean 是否通过断言
---@field message? fun(): string 断言失败消息
---@field actual? any 实际值
---@field expected? any 预期值

--- 匹配器接口
---@class (partial) Matchers<T>
---@field toBe fun(self: self, expected: any) 断言实际值与预期值是否相等(a == b). 如需深度比较, 请使用 {@link Luatest.Matchers.toEqual}.
---@field toBeTypeOf fun(self: self, expected: "nil"|"number"|"string"|"boolean"|"table"|"function"|"thread"|"userdata") 断言实际值是否属于接收类型
---@field toBeInteger fun(self: self) 实际值是否为整数
---@field toBeNil fun(self: self) 断言实际值是否为`nil`
---@field toBeDefined fun(self: self) 断言实际值是否已定义(不为`nil`)
---@field toBeCloseTo fun(self: self, expected: number, precision?: integer) 断言两个数字在给定精度范围内近似相等. 精度默认值为 `2`.
---@field toBeGreaterThan fun(self: self, expected: number) 实际值是否大于预期值
---@field toBeGreaterThanOrEqual fun(self: self, expected: number) 实际值是否大于或等于预期值
---@field toBeLessThan fun(self: self, expected: number) 实际值是否小于预期值
---@field toBeLessThanOrEqual fun(self: self, expected: number) 实际值是否小于或等于预期值
---@field toEqual fun(self: self, expected: any) 比较实际值与预期值是否相等, 如果是表, 则进行深度比较.
---@field toBeFalsy fun(self: self) 实际值是否为假值. 即是否为`nil`或`false`
---@field toBeTruthy fun(self: self) 实际值是否为真值. 即不为`nil`或`false`
---@field toBeOneOf fun(self: self, expected: any[]) 断言某个值是否与所提供数组中的任何值匹配
---@field toContain fun(self: self, expected: any) 断言数组是否包含指定值, 或字符串是否包含给定字面量子串.
---@field toContainEqual fun(self: self, expected: any) 断言数组是否包含与预期值深度相等的元素.
---@field toMatchObject fun(self: self, expected: table) 断言实际表是否包含给定表的字段子集.
---@field toHaveProperty fun(self: self, expectedPath: any[], expectedValue?: any) 断言对象包含指定路径(数组形式), 并可选比较该路径的值(深相等).
---@field toMatch fun(self: self, expected: string, plain?: boolean) 断言字符串是否与指定模式匹配. 当 `plain` 为 `true` 时, 按字符串查找, 允许仅匹配子串.
---@field toThrowError fun(self: self, expected?: any) 函数执行时是否抛出指定错误消息
---@field toHaveLength fun(self: self, expected: integer, useN?: boolean) 字符串或表是否具有指定长度. 当 `useN` 为 `true` 时会使用 `n` 字段表示长度, 默认值为 `true`.
---@field toHaveBeenCalled fun(self: self) 断言函数是否被调用过. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveBeenCalledTimes fun(self: self, expected: integer) 断言函数被调用的次数. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveBeenCalledWith fun(self: self, ...: any) 检查函数是否至少一次被调用, 并带有特定的参数. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveBeenLastCalledWith fun(self: self, ...: any) 检查函数最后一次调用时是否传入了指定参数. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveBeenNthCalledWith fun(self: self, nth: integer, ...: any) 检查函数第 n 次调用时是否传入了指定参数. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveReturned fun(self: self) 断言函数至少成功返回过一次. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveReturnedTimes fun(self: self, expected: integer) 断言函数成功返回的次数是否为预期值. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveReturnedWith fun(self: self, ...: any) 断言函数至少有一次返回值与给定实参相同. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveLastReturnedWith fun(self: self, ...: any) 检查函数最后一次返回的值是否与给定实参相同. 需要将一个 spy 函数传递给 `expect`.
---@field toHaveNthReturnedWith fun(self: self, nth: integer, ...: any) 检查函数第 n 次返回的值是否与给定实参相同. 需要将一个 spy 函数传递给 `expect`.


--- 非对称匹配器
---@class AsymmetricMatcher
---@field asymmetricMatch fun(other: any): boolean
---@field toString fun(): string
---@field getExpectedType? fun(): string
---@field toAsymmetricMatcher? fun(): string

--- 非对称匹配器接口, 用于定义各种非对称匹配器方法
---@class AsymmetricMatchers
---@field any fun(sample: any): AsymmetricMatcher
---@field anything fun(): AsymmetricMatcher
---@field arrayContaining fun(sample: any[]): AsymmetricMatcher
---@field arrayOf fun(sample: unknown): AsymmetricMatcher
---@field closeTo fun(sample: number, precision?: number): AsymmetricMatcher
---@field objectContaining fun(sample: {[string]: any}): AsymmetricMatcher
---@field stringContaining fun(sample: string): AsymmetricMatcher
---@field stringMatching fun(sample: string): AsymmetricMatcher
