#pragma once

#include "doof_runtime.hpp"
#include <cerrno>
#include <charconv>
#include <cctype>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <limits>
#include <string>
#include <system_error>

namespace doof_parse {

inline bool hasOuterWhitespace(const std::string& value) {
    if (value.empty()) return false;
    const auto first = static_cast<unsigned char>(value.front());
    const auto last = static_cast<unsigned char>(value.back());
    return std::isspace(first) || std::isspace(last);
}

template <typename T>
inline doof::Result<T, ParsingError> emptyOrInvalid(const std::string& value) {
    return doof::Failure<ParsingError>{
        value.empty() ? ParsingError::EmptyInput : ParsingError::InvalidFormat
    };
}

inline doof::Result<bool, ParsingError> parseBool(const std::string& value) {
    if (value == "true") return doof::Success<bool>{true};
    if (value == "false") return doof::Success<bool>{false};
    return emptyOrInvalid<bool>(value);
}

template <typename T>
inline doof::Result<T, ParsingError> parseInteger(const std::string& value, int32_t radix) {
    if (radix < 2 || radix > 36) {
        return doof::Failure<ParsingError>{ParsingError::InvalidRadix};
    }
    if (value.empty()) {
        return emptyOrInvalid<T>(value);
    }

    const char* first = value.data();
    const char* last = first + value.size();
    bool negative = false;
    if (*first == '+' || *first == '-') {
        negative = *first == '-';
        ++first;
    }
    if (first == last) {
        return doof::Failure<ParsingError>{ParsingError::InvalidFormat};
    }

    uint64_t magnitude = 0;
    const auto conversion = std::from_chars(first, last, magnitude, radix);
    if (conversion.ec == std::errc::invalid_argument || conversion.ptr != last) {
        return doof::Failure<ParsingError>{ParsingError::InvalidFormat};
    }
    if (conversion.ec == std::errc::result_out_of_range) {
        return doof::Failure<ParsingError>{
            negative ? ParsingError::Underflow : ParsingError::Overflow
        };
    }

    if constexpr (std::numeric_limits<T>::is_signed) {
        const uint64_t positiveLimit = static_cast<uint64_t>(std::numeric_limits<T>::max());
        if (negative) {
            const uint64_t negativeLimit = positiveLimit + 1;
            if (magnitude > negativeLimit) {
                return doof::Failure<ParsingError>{ParsingError::Underflow};
            }
            if (magnitude == negativeLimit) {
                return doof::Success<T>{std::numeric_limits<T>::min()};
            }
            return doof::Success<T>{static_cast<T>(-static_cast<int64_t>(magnitude))};
        }
        if (magnitude > positiveLimit) {
            return doof::Failure<ParsingError>{ParsingError::Overflow};
        }
        return doof::Success<T>{static_cast<T>(magnitude)};
    } else {
        if (negative && magnitude != 0) {
            return doof::Failure<ParsingError>{ParsingError::Underflow};
        }
        if (magnitude > static_cast<uint64_t>(std::numeric_limits<T>::max())) {
            return doof::Failure<ParsingError>{ParsingError::Overflow};
        }
        return doof::Success<T>{static_cast<T>(magnitude)};
    }
}

inline doof::Result<uint8_t, ParsingError> parseByte(const std::string& value) {
    return parseInteger<uint8_t>(value, 10);
}

inline doof::Result<int32_t, ParsingError> parseInt(const std::string& value) {
    return parseInteger<int32_t>(value, 10);
}

inline doof::Result<int64_t, ParsingError> parseLong(const std::string& value) {
    return parseInteger<int64_t>(value, 10);
}

inline doof::Result<uint8_t, ParsingError> parseByteRadix(const std::string& value, int32_t radix) {
    return parseInteger<uint8_t>(value, radix);
}

inline doof::Result<int32_t, ParsingError> parseIntRadix(const std::string& value, int32_t radix) {
    return parseInteger<int32_t>(value, radix);
}

inline doof::Result<int64_t, ParsingError> parseLongRadix(const std::string& value, int32_t radix) {
    return parseInteger<int64_t>(value, radix);
}

template <typename T>
inline doof::Result<T, ParsingError> parseFloating(
    const std::string& value,
    T (*convert)(const char*, char**),
    bool requireFinite = false
) {
    if (value.empty() || hasOuterWhitespace(value)) {
        return emptyOrInvalid<T>(value);
    }

    errno = 0;
    char* end = nullptr;
    const T parsed = convert(value.c_str(), &end);
    if (end == value.data() || end != value.data() + value.size()) {
        return doof::Failure<ParsingError>{ParsingError::InvalidFormat};
    }
    if (errno == ERANGE) {
        return doof::Failure<ParsingError>{
            parsed == static_cast<T>(0) ? ParsingError::Underflow : ParsingError::Overflow
        };
    }
    if (requireFinite && !std::isfinite(parsed)) {
        return doof::Failure<ParsingError>{ParsingError::NonFinite};
    }
    return doof::Success<T>{parsed};
}

inline doof::Result<float, ParsingError> parseFloat(const std::string& value) {
    return parseFloating<float>(value, std::strtof);
}

inline doof::Result<double, ParsingError> parseDouble(const std::string& value) {
    return parseFloating<double>(value, std::strtod);
}

inline doof::Result<float, ParsingError> parseFiniteFloat(const std::string& value) {
    return parseFloating<float>(value, std::strtof, true);
}

inline doof::Result<double, ParsingError> parseFiniteDouble(const std::string& value) {
    return parseFloating<double>(value, std::strtod, true);
}

} // namespace doof_parse
