export readonly PI = 3.141592653589793
export readonly TAU = 6.283185307179586
export readonly E = 2.718281828459045

export import isolated function abs<T: int | long | float | double>(x: T): T from "<cmath>" as std::abs
export import isolated function min<T: int | long | float | double>(a: T, b: T): T from "<algorithm>" as std::min
export import isolated function max<T: int | long | float | double>(a: T, b: T): T from "<algorithm>" as std::max
import isolated function nativeClamp<T: int | long | float | double>(x: T, lo: T, hi: T): T from "<algorithm>" as std::clamp

export isolated function clamp<T: int | long | float | double>(x: T, lo: T, hi: T): T {
    if lo > hi {
        panic("clamp lower bound must not exceed upper bound")
    }
    return nativeClamp(x, lo, hi)
}

export import isolated function sin<T: float | double>(x: T): T from "<cmath>" as std::sin
export import isolated function cos<T: float | double>(x: T): T from "<cmath>" as std::cos
export import isolated function tan<T: float | double>(x: T): T from "<cmath>" as std::tan
export import isolated function asin<T: float | double>(x: T): T from "<cmath>" as std::asin
export import isolated function acos<T: float | double>(x: T): T from "<cmath>" as std::acos
export import isolated function atan<T: float | double>(x: T): T from "<cmath>" as std::atan
export import isolated function atan2<T: float | double>(y: T, x: T): T from "<cmath>" as std::atan2
export import isolated function sqrt<T: float | double>(x: T): T from "<cmath>" as std::sqrt
export import isolated function cbrt<T: float | double>(x: T): T from "<cmath>" as std::cbrt
export import isolated function pow<T: float | double>(base: T, exponent: T): T from "<cmath>" as std::pow
export import isolated function exp<T: float | double>(x: T): T from "<cmath>" as std::exp
export import isolated function expm1<T: float | double>(x: T): T from "<cmath>" as std::expm1
export import isolated function log<T: float | double>(x: T): T from "<cmath>" as std::log
export import isolated function log1p<T: float | double>(x: T): T from "<cmath>" as std::log1p
export import isolated function floor<T: float | double>(x: T): T from "<cmath>" as std::floor
export import isolated function ceil<T: float | double>(x: T): T from "<cmath>" as std::ceil
export import isolated function round<T: float | double>(x: T): T from "<cmath>" as std::round
export import isolated function trunc<T: float | double>(x: T): T from "<cmath>" as std::trunc
export import isolated function hypot<T: float | double>(x: T, y: T): T from "<cmath>" as std::hypot
export import isolated function log2<T: float | double>(x: T): T from "<cmath>" as std::log2
export import isolated function log10<T: float | double>(x: T): T from "<cmath>" as std::log10
export import isolated function copysign<T: float | double>(magnitude: T, sign: T): T from "<cmath>" as std::copysign
export import isolated function isnan<T: float | double>(x: T): bool from "<cmath>" as std::isnan
export import isolated function isinf<T: float | double>(x: T): bool from "<cmath>" as std::isinf
export import isolated function isfinite<T: float | double>(x: T): bool from "<cmath>" as std::isfinite

export function radians(degrees: double): double => degrees * (PI / 180.0)

export function degrees(radiansValue: double): double => radiansValue * (180.0 / PI)

export function lerp(a: double, b: double, t: double): double => a + (b - a) * t

export function approxEqual(a: double, b: double, tolerance: double = 0.000001): bool {
    if tolerance < 0.0 {
        panic("approxEqual tolerance must not be negative")
    }
    if a == b {
        return true
    }
    return abs(a - b) <= tolerance
}

export import isolated function fmod<T: float | double>(x: T, y: T): T from "<cmath>" as std::fmod

export function mod(x: double, y: double): double {
    if y <= 0.0 || !isfinite(y) {
        panic("mod divisor must be finite and greater than zero")
    }
    return fmod(fmod(x, y) + y, y)
}

export function wrapRadians(angle: double): double {
    return mod(angle + PI, TAU) - PI
}
