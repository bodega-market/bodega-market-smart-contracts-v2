use aiken/collection/dict
use aiken/collection/list
use aiken/interval
use bodega/test_constants.{
  pmanager_nft_asset, pmanager_nft_tn, protocol_nft_policy_id,
}
use bodega/types.{Asset}
use cardano/address.{from_script}
use cardano/assets
use cardano/transaction.{Input, NoDatum, Output, OutputReference, Transaction}

pub type PTreasuryRedeemer {
  pmanager_in_idx: Int,
}

validator protocol_treasury(psettings_nft: Asset) {
  spend(
    _datum: Option<Data>,
    redeemer: PTreasuryRedeemer,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    let Transaction { inputs, .. } = self
    expect Some(psetting_input) = list.at(inputs, redeemer.pmanager_in_idx)
    assets.quantity_of(
      psetting_input.output.value,
      psettings_nft.policy_id,
      psettings_nft.asset_name,
    ) == 1
  }

  else(_) {
    fail
  }
}

test protocol_treasury__spend() {
  let ptreasury_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let ptreasury_input =
    Input {
      output_reference: ptreasury_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.from_lovelace(200_000_000),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let pmanager_out_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let pmanager_input =
    Input {
      output_reference: pmanager_out_ref,
      output: Output {
        address: from_script(#""),
        value: assets.from_lovelace(2_000_000)
          |> assets.add(protocol_nft_policy_id, pmanager_nft_tn, 1),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let ptreasury_redeemer = PTreasuryRedeemer { pmanager_in_idx: 1 }
  let tx =
    Transaction {
      inputs: [ptreasury_input, pmanager_input],
      reference_inputs: [],
      outputs: [],
      fee: 0,
      mint: assets.zero,
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
  protocol_treasury.spend(
    pmanager_nft_asset,
    None,
    ptreasury_redeemer,
    ptreasury_ref,
    tx,
  )
}
