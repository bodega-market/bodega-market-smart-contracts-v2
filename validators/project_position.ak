use aiken/collection/dict
use aiken/collection/list
use aiken/interval
use bodega/constants.{project_prediction_nft_tn}
use bodega/test_constants.{
  project_prediction_nft_asset, project_prediction_nft_policy_id,
  share_policy_id,
}
use bodega/types.{Asset, BuyPos, PositionDatum, RefundPos, RewardPos}
use cardano/address.{from_script}
use cardano/assets
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}

pub type PositionRedeemer {
  pred_in_idx: Int,
}

validator positions(prediction_nft: Asset) {
  spend(
    _datum: Option<PositionDatum>,
    redeemer: PositionRedeemer,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    let Transaction { inputs, .. } = self

    expect Some(pred_input) = list.at(inputs, redeemer.pred_in_idx)
    assets.quantity_of(
      pred_input.output.value,
      prediction_nft.policy_id,
      prediction_nft.asset_name,
    ) == 1
  }

  else(_) {
    fail
  }
}

test positions__spend_buy_pos() {
  let project_info_ref_id =
    OutputReference {
      transaction_id: #"d07f157faf99b850b4971034feee28",
      output_index: 0,
    }
  let position_datum =
    PositionDatum {
      outref_id: project_info_ref_id,
      pos_user_pkh: #"6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b",
      pos_user_stake_key: #"c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3",
      pos_type: BuyPos,
      pos_amount: 10,
      pos_batcher_fee: 30_000,
      pos_candidate: "cand_1",
    }
  let position_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let position_input =
    Input {
      output_reference: position_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(share_policy_id, "cand_1", 1),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }
  let prediction_out_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let prediction_input =
    Input {
      output_reference: prediction_out_ref,
      output: Output {
        address: from_script(#""),
        value: assets.from_lovelace(2_000_000)
          |> assets.add(
              project_prediction_nft_policy_id,
              project_prediction_nft_tn,
              1,
            ),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let position_redeemer = PositionRedeemer { pred_in_idx: 1 }
  let tx =
    Transaction {
      inputs: [position_input, prediction_input],
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
  positions.spend(
    project_prediction_nft_asset,
    Some(position_datum),
    position_redeemer,
    position_ref,
    tx,
  )
}

test positions__spend_reward_pos() {
  let project_info_ref_id =
    OutputReference {
      transaction_id: #"d07f157faf99b850b4971034feee28",
      output_index: 0,
    }
  let position_datum =
    PositionDatum {
      outref_id: project_info_ref_id,
      pos_user_pkh: #"6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b",
      pos_user_stake_key: #"c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3",
      pos_type: RewardPos,
      pos_amount: 10,
      pos_batcher_fee: 30_000,
      pos_candidate: "cand_1",
    }
  let position_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let position_input =
    Input {
      output_reference: position_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(share_policy_id, "cand_1", 1),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }
  let prediction_out_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let prediction_input =
    Input {
      output_reference: prediction_out_ref,
      output: Output {
        address: from_script(#""),
        value: assets.from_lovelace(2_000_000)
          |> assets.add(
              project_prediction_nft_policy_id,
              project_prediction_nft_tn,
              1,
            ),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let position_redeemer = PositionRedeemer { pred_in_idx: 1 }
  let tx =
    Transaction {
      inputs: [position_input, prediction_input],
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
  positions.spend(
    project_prediction_nft_asset,
    Some(position_datum),
    position_redeemer,
    position_ref,
    tx,
  )
}

test positions__spend_refund_pos() {
  let project_info_ref_id =
    OutputReference {
      transaction_id: #"d07f157faf99b850b4971034feee28",
      output_index: 0,
    }
  let position_datum =
    PositionDatum {
      outref_id: project_info_ref_id,
      pos_user_pkh: #"6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b",
      pos_user_stake_key: #"c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3",
      pos_type: RefundPos,
      pos_amount: 10,
      pos_batcher_fee: 30_000,
      pos_candidate: "cand_1",
    }
  let position_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let position_input =
    Input {
      output_reference: position_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(share_policy_id, "cand_1", 1),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }
  let prediction_out_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let prediction_input =
    Input {
      output_reference: prediction_out_ref,
      output: Output {
        address: from_script(#""),
        value: assets.from_lovelace(2_000_000)
          |> assets.add(
              project_prediction_nft_policy_id,
              project_prediction_nft_tn,
              1,
            ),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let position_redeemer = PositionRedeemer { pred_in_idx: 1 }
  let tx =
    Transaction {
      inputs: [position_input, prediction_input],
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
  positions.spend(
    project_prediction_nft_asset,
    Some(position_datum),
    position_redeemer,
    position_ref,
    tx,
  )
}
