use aiken/collection/dict
use aiken/collection/list
use aiken/interval
use bodega/constants.{pmanager_nft_tn, psetting_nft_tn}
use bodega/test_constants.{pmanager_nft_asset, protocol_nft_policy_id}
use bodega/types.{Asset, PSettingDatum}
use cardano/address.{from_script}
use cardano/assets
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}

pub type PSettingRedeemer {
  pmanager_in_idx: Int,
}

validator protocol_settings(pmanager_nft: Asset) {
  spend(
    _datum: Option<PSettingDatum>,
    redeemer: PSettingRedeemer,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    let Transaction { inputs, .. } = self
    expect Some(pmanager_input) = list.at(inputs, redeemer.pmanager_in_idx)
    assets.quantity_of(
      pmanager_input.output.value,
      pmanager_nft.policy_id,
      pmanager_nft.asset_name,
    ) == 1
  }

  else(_) {
    fail
  }
}

test protocol_settings__spend() {
  let psetting_datum =
    PSettingDatum {
      pledge: 100_000_000,
      pledge_policy_id: #"",
      pledge_token_name: #"",
      protocol_treasury_script_hash: #"b4971034feee",
      share_ratio: 20000,
      open_fee: 20_000_000,
      open_fee_policy_id: #"",
      open_fee_token_name: #"",
      project_authtoken_policy_id: #"",
      project_info_token_name: #"",
      project_prediction_token_name: #"",
      protocol_stake_key_hash: #"",
    }
  let psetting_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let psetting_input =
    Input {
      output_reference: psetting_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(protocol_nft_policy_id, psetting_nft_tn, 1),
        datum: InlineDatum(psetting_datum),
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
  let psetting_redeemer = PSettingRedeemer { pmanager_in_idx: 1 }
  let tx =
    Transaction {
      inputs: [psetting_input, pmanager_input],
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
  protocol_settings.spend(
    pmanager_nft_asset,
    Some(psetting_datum),
    psetting_redeemer,
    psetting_ref,
    tx,
  )
}
