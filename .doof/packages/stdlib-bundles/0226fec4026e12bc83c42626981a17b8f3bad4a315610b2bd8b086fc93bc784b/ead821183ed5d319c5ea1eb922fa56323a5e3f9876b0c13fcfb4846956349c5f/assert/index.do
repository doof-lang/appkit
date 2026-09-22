import { approxEqual as mathApproxEqual } from "std/math"

export class Assert {
    private static check(
        condition: bool,
        expectation: string,
        message: string | none,
        source: SourceLocation,
    ) {
        if condition {
            return
        }

        failure := if message == none then expectation else
            (message ?? "") + ": " + expectation
        assert(false, failure + " at " + source.fileName + ":" + string(source.line))
    }

    static equal<T>(
        actual: T,
        expected: T,
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        Assert.check(actual == expected, "expected values to be equal", message, source)
    }

    static arrayEqual<T>(
        actual: readonly T[],
        expected: readonly T[],
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        Assert.check(actual.length == expected.length, "expected arrays to have equal length", message, source)

        for index of 0..<actual.length {
            if actual[index] == expected[index] {
                continue
            }
            Assert.check(
                false,
                "expected arrays to be equal at index " + string(index),
                message,
                source,
            )
        }
    }

    static mutableArrayEqual<T>(
        actual: T[],
        expected: readonly T[],
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        Assert.check(actual.length == expected.length, "expected arrays to have equal length", message, source)

        for index of 0..<actual.length {
            if actual[index] == expected[index] {
                continue
            }
            Assert.check(
                false,
                "expected arrays to be equal at index " + string(index),
                message,
                source,
            )
        }
    }

    static setEqual<T>(
        actual: ReadonlySet<T>,
        expected: ReadonlySet<T>,
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        Assert.check(actual.size == expected.size, "expected sets to have equal size", message, source)

        for value of actual {
            Assert.check(expected.has(value), "expected sets to contain equal values", message, source)
        }
    }

    static mutableSetEqual<T>(
        actual: Set<T>,
        expected: ReadonlySet<T>,
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        Assert.check(actual.size == expected.size, "expected sets to have equal size", message, source)

        for value of actual {
            Assert.check(expected.has(value), "expected sets to contain equal values", message, source)
        }
    }

    static mapEqual<K, V>(
        actual: ReadonlyMap<K, V>,
        expected: ReadonlyMap<K, V>,
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        Assert.check(actual.size == expected.size, "expected maps to have equal size", message, source)

        for key, value of actual {
            expectedValue := expected.get(key)
            case expectedValue {
                success: Success -> Assert.check(
                    value == success.value,
                    "expected maps to contain equal entries",
                    message,
                    source,
                ),
                _: Failure -> Assert.check(
                    false,
                    "expected maps to contain equal keys",
                    message,
                    source,
                ),
            }
        }
    }

    static mutableMapEqual<K, V>(
        actual: Map<K, V>,
        expected: ReadonlyMap<K, V>,
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        Assert.check(actual.size == expected.size, "expected maps to have equal size", message, source)

        for key, value of actual {
            expectedValue := expected.get(key)
            case expectedValue {
                success: Success -> Assert.check(
                    value == success.value,
                    "expected maps to contain equal entries",
                    message,
                    source,
                ),
                _: Failure -> Assert.check(
                    false,
                    "expected maps to contain equal keys",
                    message,
                    source,
                ),
            }
        }
    }

    static approxEqual(
        actual: double,
        expected: double,
        tolerance: double = 0.000001,
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        Assert.check(
            mathApproxEqual(actual, expected, tolerance),
            "expected values to be approximately equal",
            message,
            source,
        )
    }

    static notEqual<T>(
        actual: T,
        expected: T,
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        Assert.check(!(actual == expected), "expected values to differ", message, source)
    }

    static isTrue(
        value: bool,
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        Assert.check(value, "expected value to be true", message, source)
    }

    static isFalse(
        value: bool,
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        Assert.check(!value, "expected value to be false", message, source)
    }

    static contains<T>(
        values: readonly T[],
        expected: T,
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        Assert.check(values.contains(expected), "expected array to contain value", message, source)
    }

    static notContains<T>(
        values: readonly T[],
        expected: T,
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        Assert.check(!values.contains(expected), "expected array not to contain value", message, source)
    }

    static mutableArrayContains<T>(
        values: T[],
        expected: T,
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        Assert.check(values.contains(expected), "expected array to contain value", message, source)
    }

    static mutableArrayNotContains<T>(
        values: T[],
        expected: T,
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        Assert.check(!values.contains(expected), "expected array not to contain value", message, source)
    }

    static stringContains(
        value: string,
        expected: string,
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        expectation := "expected string to contain \"" + expected + "\""
        Assert.check(value.contains(expected), expectation, message, source)
    }

    static stringNotContains(
        value: string,
        expected: string,
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        expectation := "expected string not to contain \"" + expected + "\""
        Assert.check(!value.contains(expected), expectation, message, source)
    }

    static fail(
        message: string | none = none,
        source: SourceLocation = @caller,
    ) {
        if message == none {
            Assert.check(false, "test failed", none, source)
        } else {
            Assert.check(false, message ?? "test failed", none, source)
        }
    }
}
