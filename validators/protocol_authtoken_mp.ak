use aiken/collection/dict
use aiken/collection/list
use aiken/interval
use aiken/primitive/string
use cardano/address.{from_verification_key}
use cardano/assets
use cardano/transaction.{Input, NoDatum, Output, OutputReference, Transaction}

validator protocol_authtoken_mp(seed: OutputReference) {
  mint(_redeemer: Data, policy_id: ByteArray, self: Transaction) {
    let Transaction { inputs, mint, .. } = self
    expect
      list.any(
        inputs,
        fn(inp) { inp.output_reference.transaction_id == seed.transaction_id },
      )
    expect [Pair(tn, amt),
      Pair(tn1, amt1)] =
      mint
        |> assets.tokens(policy_id)
        |> dict.to_pairs()
    expect tn == string.to_bytearray(@"PROTOCOL_MANAGER_NFT") && amt == 1
    expect tn1 == string.to_bytearray(@"PROTOCOL_SETTINGS_NFT") && amt1 == 1
    True
  }

  else(_) {
    fail
  }
}

test protocol_authtoken_mp_success() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let seed_input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_verification_key(#""),
        value: assets.from_lovelace(2_000_000),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let own_policy_id =
    #"a5ff2c36e9eeb9655d06c0a2f02d9e200aa6f8db00d760acf62c0eba"
  let mint =
    assets.from_asset(
      own_policy_id,
      string.to_bytearray(@"PROTOCOL_SETTINGS_NFT"),
      1,
    )
      |> assets.add(
          own_policy_id,
          string.to_bytearray(@"PROTOCOL_MANAGER_NFT"),
          1,
        )
  let tx =
    Transaction {
      inputs: [seed_input],
      reference_inputs: [],
      outputs: [],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: interval.everything,
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  protocol_authtoken_mp.mint(own_ref, 1, own_policy_id, tx)
}
