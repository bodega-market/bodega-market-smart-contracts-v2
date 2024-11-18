use aiken/builtin
use aiken/collection/dict
use aiken/interval.{Finite}
use aiken/primitive/bytearray
use aiken/primitive/string
use cardano/assets.{PolicyId, Value}
use cardano/transaction.{ValidityRange}

pub const decimals = 1_000_000

pub const multiplier = 10_000

const minus_ascii_code = 45

const zero_ascii_code = 48

pub fn find_posix_time_range(time_rage: ValidityRange) -> (Int, Int) {
  expect Finite(t1) = time_rage.lower_bound.bound_type
  expect Finite(t2) = time_rage.upper_bound.bound_type
  (t1, t2)
}

pub fn find_license_deadline(license_symbol: PolicyId, val: Value) -> Int {
  expect [Pair(tn, am)] =
    val
      |> assets.tokens(license_symbol)
      |> dict.to_pairs()
  expect am == 1
  bytearray_to_int(tn)
}

pub fn bytearray_to_int(byte_arr: ByteArray) -> Int {
  let byte_len = bytearray.length(byte_arr)
  do_bytearray_to_int(byte_arr, 0, 0, byte_len)
}

pub fn do_bytearray_to_int(
  byte_arr: ByteArray,
  idx: Int,
  acc: Int,
  byte_len: Int,
) -> Int {
  if idx == byte_len {
    acc
  } else {
    let byte = builtin.index_bytearray(byte_arr, idx)
    if idx == 0 && byte == minus_ascii_code {
      do_bytearray_to_int(byte_arr, idx + 1, acc, byte_len) * -1
    } else if byte < zero_ascii_code || byte > zero_ascii_code + 9 {
      fail
    } else {
      do_bytearray_to_int(
        byte_arr,
        idx + 1,
        acc * 10 + ( byte - zero_ascii_code ),
        byte_len,
      )
    }
  }
}

test test_bytearray_to_int() {
  let r1 = bytearray_to_int(string.to_bytearray(@"123"))
  let r2 = bytearray_to_int(string.to_bytearray(@"111"))
  r1 == 123 && r2 == 111
}
