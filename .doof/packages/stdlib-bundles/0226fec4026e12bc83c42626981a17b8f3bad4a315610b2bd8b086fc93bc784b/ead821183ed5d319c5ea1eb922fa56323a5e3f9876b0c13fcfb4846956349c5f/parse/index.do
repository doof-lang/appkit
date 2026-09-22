export { ParsingError } from "./types"

export import isolated function parseBool(value: string): Result<bool, ParsingError>
  from "native_parse.hpp" as doof_parse::parseBool

export import isolated function parseByte(value: string): Result<byte, ParsingError>
  from "native_parse.hpp" as doof_parse::parseByte

export import isolated function parseInt(value: string): Result<int, ParsingError>
  from "native_parse.hpp" as doof_parse::parseInt

export import isolated function parseLong(value: string): Result<long, ParsingError>
  from "native_parse.hpp" as doof_parse::parseLong

export import isolated function parseByteRadix(value: string, radix: int): Result<byte, ParsingError>
  from "native_parse.hpp" as doof_parse::parseByteRadix

export import isolated function parseIntRadix(value: string, radix: int): Result<int, ParsingError>
  from "native_parse.hpp" as doof_parse::parseIntRadix

export import isolated function parseLongRadix(value: string, radix: int): Result<long, ParsingError>
  from "native_parse.hpp" as doof_parse::parseLongRadix

export import isolated function parseFloat(value: string): Result<float, ParsingError>
  from "native_parse.hpp" as doof_parse::parseFloat

export import isolated function parseDouble(value: string): Result<double, ParsingError>
  from "native_parse.hpp" as doof_parse::parseDouble

export import isolated function parseFiniteFloat(value: string): Result<float, ParsingError>
  from "native_parse.hpp" as doof_parse::parseFiniteFloat

export import isolated function parseFiniteDouble(value: string): Result<double, ParsingError>
  from "native_parse.hpp" as doof_parse::parseFiniteDouble
