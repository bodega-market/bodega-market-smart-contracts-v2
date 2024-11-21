use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Finite, Interval, IntervalBound}
use bodega/constants.{project_info_nft_tn, project_prediction_nft_tn}
use bodega/test_constants.{
  pos_user_pkh, pos_user_stake_key, project_info_nft_asset,
  project_info_nft_policy_id, project_prediction_nft_asset,
  project_prediction_nft_policy_id, share_policy_id,
}
use bodega/types.{
  Asset, BuyPos, PositionDatum, ProjectInfoDatum, ProjectPredictionDatum,
}
use bodega/utils.{decimals, find_posix_time_range, multiplier}
use cardano/address.{Address, Script, from_script}
use cardano/assets.{PolicyId, flatten}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}

pub type ShareRedeemer {
  Buy { project_info_ref_idx: Int }
  Reward { pred_in_idx: Int }
  Refund { pred_in_idx: Int }
}

pub type ShareParams {
  project_info_nft: Asset,
  project_prediction_nft: Asset,
}

validator project_shares(params: ShareParams) {
  mint(redeemer: ShareRedeemer, policy_id: PolicyId, self: Transaction) {
    let Transaction {
      mint,
      inputs,
      reference_inputs,
      outputs,
      validity_range,
      ..
    } = self
    let flatten_mint = flatten(mint)
    when redeemer is {
      Buy { project_info_ref_idx } -> {
        expect Some(project_info_ref_input) =
          list.at(reference_inputs, project_info_ref_idx)
        expect
          assets.quantity_of(
            project_info_ref_input.output.value,
            params.project_info_nft.policy_id,
            params.project_info_nft.asset_name,
          ) == 1
        expect InlineDatum(project_info_output_datum) =
          project_info_ref_input.output.datum
        expect project_info_datum: ProjectInfoDatum = project_info_output_datum
        let (_start_valid_time_range, end_valid_time_range) =
          find_posix_time_range(validity_range)
        expect end_valid_time_range < project_info_datum.deadline
        let pos_script_cred = Script(project_info_datum.position_script_hash)
        let pos_outputs =
          list.filter(
            outputs,
            fn(output) {
              let Output { address: Address { payment_credential, .. }, .. } =
                output
              expect payment_credential == pos_script_cred
              expect InlineDatum(pos_output_datum) = output.datum
              expect pos_datum: PositionDatum = pos_output_datum
              expect pos_datum.pos_batcher_fee > 0 && pos_datum.pos_amount > 0
              expect pos_datum.pos_type == BuyPos
              let admin_fee_amount =
                pos_datum.pos_amount * project_info_datum.admin_fee_percent * decimals / multiplier
              let min_lovelace =
                pos_datum.pos_batcher_fee + project_info_datum.envelope_amount
              let min_payment =
                pos_datum.pos_amount * decimals + admin_fee_amount
              let out_pos_lovelace = assets.lovelace_of(output.value)
              if project_info_datum.payment_policy_id == assets.ada_policy_id {
                out_pos_lovelace >= min_payment + min_lovelace
              } else {
                out_pos_lovelace >= min_lovelace && assets.quantity_of(
                  output.value,
                  project_info_datum.payment_policy_id,
                  project_info_datum.payment_token_name,
                ) >= min_payment
              }
            },
          )
        expect [pos_output] = pos_outputs
        expect InlineDatum(pos_output_datum) = pos_output.datum
        expect pos_datum: PositionDatum = pos_output_datum
        expect
          assets.quantity_of(
            pos_output.value,
            policy_id,
            pos_datum.pos_candidate,
          ) == pos_datum.pos_amount
        [(policy_id, pos_datum.pos_candidate, pos_datum.pos_amount)] == flatten_mint
      }
      Reward { pred_in_idx } -> {
        expect Some(pred_input) = list.at(inputs, pred_in_idx)
        assets.quantity_of(
          pred_input.output.value,
          params.project_prediction_nft.policy_id,
          params.project_prediction_nft.asset_name,
        ) == 1
      }
      Refund { pred_in_idx } -> {
        expect Some(pred_input) = list.at(inputs, pred_in_idx)
        assets.quantity_of(
          pred_input.output.value,
          params.project_prediction_nft.policy_id,
          params.project_prediction_nft.asset_name,
        ) == 1
      }
    }
  }

  else(_) {
    fail
  }
}

test shares__mint_reward() {
  let pred_datum =
    ProjectPredictionDatum {
      total_fee: 100_000_000,
      predictions: [Pair("cand_1", 10), Pair("cand_2", 20)],
    }
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let pred_input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(#""),
        value: assets.from_lovelace(2_000_000)
          |> assets.add(
              project_prediction_nft_policy_id,
              project_prediction_nft_tn,
              1,
            ),
        datum: InlineDatum(pred_datum),
        reference_script: None,
      },
    }
  let mint = assets.from_asset(share_policy_id, "cand_1", -10)
  let tx =
    Transaction {
      inputs: [pred_input],
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
  let params =
    ShareParams {
      project_info_nft: project_info_nft_asset,
      project_prediction_nft: project_prediction_nft_asset,
    }
  let redeemer = Reward { pred_in_idx: 0 }
  project_shares.mint(params, redeemer, share_policy_id, tx)
}

test shares__mint_refund() {
  let pred_datum =
    ProjectPredictionDatum {
      total_fee: 100_000_000,
      predictions: [Pair("cand_1", 10), Pair("cand_2", 20)],
    }
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let pred_input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(#""),
        value: assets.from_lovelace(2_000_000)
          |> assets.add(
              project_prediction_nft_policy_id,
              project_prediction_nft_tn,
              1,
            ),
        datum: InlineDatum(pred_datum),
        reference_script: None,
      },
    }
  let mint = assets.from_asset(share_policy_id, "cand_1", -10)
  let tx =
    Transaction {
      inputs: [pred_input],
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
  let params =
    ShareParams {
      project_info_nft: project_info_nft_asset,
      project_prediction_nft: project_prediction_nft_asset,
    }
  let redeemer = Refund { pred_in_idx: 0 }
  project_shares.mint(params, redeemer, share_policy_id, tx)
}

test shares__mint_buy() {
  let project_info_datum =
    ProjectInfoDatum {
      owner_pkh: #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      project_name: "test",
      deadline: 1730394000000,
      payment_policy_id: #"3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe",
      payment_token_name: "token_name",
      batcher_policy_id: #"6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e",
      treasury_script_hash: #"f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2",
      position_script_hash: #"702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86",
      share_policy_id: #"2d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c425",
      oracle_policy_id: #"f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9",
      oracle_token_name: "oracle_token_name",
      admin_fee_percent: 500,
      // ^ base 10_000
      envelope_amount: 2_000_000,
      candidates: ["cand_1", "cand_2"],
    }
  let project_info_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let project_info_input =
    Input {
      output_reference: project_info_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(project_info_nft_policy_id, project_info_nft_tn, 1),
        datum: InlineDatum(project_info_datum),
        reference_script: None,
      },
    }
  let mint = assets.from_asset(share_policy_id, "cand_1", 10)
  let pos_datum =
    PositionDatum {
      pos_user_pkh,
      pos_user_stake_key,
      pos_type: BuyPos,
      pos_amount: 10,
      pos_batcher_fee: 300_000,
      pos_candidate: "cand_1",
    }
  let pos_out =
    Output {
      address: from_script(project_info_datum.position_script_hash),
      value: mint
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            10 * ( multiplier + project_info_datum.admin_fee_percent ) * decimals / multiplier,
          )
        |> assets.merge(assets.from_lovelace(2_300_000)),
      datum: InlineDatum(pos_datum),
      reference_script: None,
    }
  let tx =
    Transaction {
      inputs: [],
      reference_inputs: [project_info_input],
      outputs: [pos_out],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let params =
    ShareParams {
      project_info_nft: project_info_nft_asset,
      project_prediction_nft: project_prediction_nft_asset,
    }
  let redeemer = Buy { project_info_ref_idx: 0 }
  project_shares.mint(params, redeemer, share_policy_id, tx)
}

test shares__mint_buy_incorrect_time_range() fail {
  let project_info_datum =
    ProjectInfoDatum {
      owner_pkh: #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      project_name: "test",
      deadline: 1730394000000,
      payment_policy_id: #"3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe",
      payment_token_name: "token_name",
      batcher_policy_id: #"6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e",
      treasury_script_hash: #"f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2",
      position_script_hash: #"702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86",
      share_policy_id: #"2d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c425",
      oracle_policy_id: #"f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9",
      oracle_token_name: "oracle_token_name",
      admin_fee_percent: 500,
      // ^ base 10_000
      envelope_amount: 2_000_000,
      candidates: ["cand_1", "cand_2"],
    }
  let project_info_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let project_info_input =
    Input {
      output_reference: project_info_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(project_info_nft_policy_id, project_info_nft_tn, 1),
        datum: InlineDatum(project_info_datum),
        reference_script: None,
      },
    }
  let mint = assets.from_asset(share_policy_id, "cand_1", 10)
  let pos_datum =
    PositionDatum {
      pos_user_pkh,
      pos_user_stake_key,
      pos_type: BuyPos,
      pos_amount: 10,
      pos_batcher_fee: 300_000,
      pos_candidate: "cand_1",
    }
  let pos_out =
    Output {
      address: from_script(project_info_datum.position_script_hash),
      value: mint
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            10 * ( multiplier + project_info_datum.admin_fee_percent ) * decimals / multiplier,
          )
        |> assets.merge(assets.from_lovelace(2_300_000)),
      datum: InlineDatum(pos_datum),
      reference_script: None,
    }
  let tx =
    Transaction {
      inputs: [],
      reference_inputs: [project_info_input],
      outputs: [pos_out],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1730394000001),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let params =
    ShareParams {
      project_info_nft: project_info_nft_asset,
      project_prediction_nft: project_prediction_nft_asset,
    }
  let redeemer = Buy { project_info_ref_idx: 0 }
  project_shares.mint(params, redeemer, share_policy_id, tx)
}

test shares__mint_buy__incorrect_fee() fail {
  let project_info_datum =
    ProjectInfoDatum {
      owner_pkh: #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      project_name: "test",
      deadline: 1730394000000,
      payment_policy_id: #"3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe",
      payment_token_name: "token_name",
      batcher_policy_id: #"6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e",
      treasury_script_hash: #"f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2",
      position_script_hash: #"702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86",
      share_policy_id: #"2d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c425",
      oracle_policy_id: #"f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9",
      oracle_token_name: "oracle_token_name",
      admin_fee_percent: 500,
      // ^ base 10_000
      envelope_amount: 2_000_000,
      candidates: ["cand_1", "cand_2"],
    }
  let project_info_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let project_info_input =
    Input {
      output_reference: project_info_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(project_info_nft_policy_id, project_info_nft_tn, 1),
        datum: InlineDatum(project_info_datum),
        reference_script: None,
      },
    }
  let mint = assets.from_asset(share_policy_id, "cand_1", 10)
  let pos_datum =
    PositionDatum {
      pos_user_pkh,
      pos_user_stake_key,
      pos_type: BuyPos,
      pos_amount: 10,
      pos_batcher_fee: 300_000,
      pos_candidate: "cand_1",
    }
  let pos_out =
    Output {
      address: from_script(project_info_datum.position_script_hash),
      value: mint
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            10 * decimals / multiplier,
          )
        |> assets.merge(assets.from_lovelace(2_300_000)),
      datum: InlineDatum(pos_datum),
      reference_script: None,
    }
  let tx =
    Transaction {
      inputs: [],
      reference_inputs: [project_info_input],
      outputs: [pos_out],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let params =
    ShareParams {
      project_info_nft: project_info_nft_asset,
      project_prediction_nft: project_prediction_nft_asset,
    }
  let redeemer = Buy { project_info_ref_idx: 0 }
  project_shares.mint(params, redeemer, share_policy_id, tx)
}

test shares__mint_buy__incorrect_mint() fail {
  let project_info_datum =
    ProjectInfoDatum {
      owner_pkh: #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      project_name: "test",
      deadline: 1730394000000,
      payment_policy_id: #"3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe",
      payment_token_name: "token_name",
      batcher_policy_id: #"6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e",
      treasury_script_hash: #"f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2",
      position_script_hash: #"702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86",
      share_policy_id: #"2d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c425",
      oracle_policy_id: #"f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9",
      oracle_token_name: "oracle_token_name",
      admin_fee_percent: 500,
      // ^ base 10_000
      envelope_amount: 2_000_000,
      candidates: ["cand_1", "cand_2"],
    }
  let project_info_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let project_info_input =
    Input {
      output_reference: project_info_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(project_info_nft_policy_id, project_info_nft_tn, 1),
        datum: InlineDatum(project_info_datum),
        reference_script: None,
      },
    }
  let mint = assets.from_asset(share_policy_id, "cand_2", 10)
  let pos_datum =
    PositionDatum {
      pos_user_pkh,
      pos_user_stake_key,
      pos_type: BuyPos,
      pos_amount: 10,
      pos_batcher_fee: 300_000,
      pos_candidate: "cand_1",
    }
  let pos_out =
    Output {
      address: from_script(project_info_datum.position_script_hash),
      value: mint
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            10 * decimals / multiplier,
          )
        |> assets.merge(assets.from_lovelace(2_300_000)),
      datum: InlineDatum(pos_datum),
      reference_script: None,
    }
  let tx =
    Transaction {
      inputs: [],
      reference_inputs: [project_info_input],
      outputs: [pos_out],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let params =
    ShareParams {
      project_info_nft: project_info_nft_asset,
      project_prediction_nft: project_prediction_nft_asset,
    }
  let redeemer = Buy { project_info_ref_idx: 0 }
  project_shares.mint(params, redeemer, share_policy_id, tx)
}

test shares__mint_buy__incorrect_candidate() fail {
  let project_info_datum =
    ProjectInfoDatum {
      owner_pkh: #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      project_name: "test",
      deadline: 1730394000000,
      payment_policy_id: #"3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe",
      payment_token_name: "token_name",
      batcher_policy_id: #"6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e",
      treasury_script_hash: #"f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2",
      position_script_hash: #"702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86",
      share_policy_id: #"2d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c425",
      oracle_policy_id: #"f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9",
      oracle_token_name: "oracle_token_name",
      admin_fee_percent: 500,
      // ^ base 10_000
      envelope_amount: 2_000_000,
      candidates: ["cand_1", "cand_2"],
    }
  let project_info_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let project_info_input =
    Input {
      output_reference: project_info_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(project_info_nft_policy_id, project_info_nft_tn, 1),
        datum: InlineDatum(project_info_datum),
        reference_script: None,
      },
    }
  let mint = assets.from_asset(share_policy_id, "cand_3", 10)
  let pos_datum =
    PositionDatum {
      pos_user_pkh,
      pos_user_stake_key,
      pos_type: BuyPos,
      pos_amount: 10,
      pos_batcher_fee: 300_000,
      pos_candidate: "cand_1",
    }
  let pos_out =
    Output {
      address: from_script(project_info_datum.position_script_hash),
      value: mint
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            10 * decimals / multiplier,
          )
        |> assets.merge(assets.from_lovelace(2_300_000)),
      datum: InlineDatum(pos_datum),
      reference_script: None,
    }
  let tx =
    Transaction {
      inputs: [],
      reference_inputs: [project_info_input],
      outputs: [pos_out],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let params =
    ShareParams {
      project_info_nft: project_info_nft_asset,
      project_prediction_nft: project_prediction_nft_asset,
    }
  let redeemer = Buy { project_info_ref_idx: 0 }
  project_shares.mint(params, redeemer, share_policy_id, tx)
}

test shares__mint_buy__ada_payment() {
  let project_info_datum =
    ProjectInfoDatum {
      owner_pkh: #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      project_name: "test",
      deadline: 1730394000000,
      payment_policy_id: #"",
      payment_token_name: "",
      batcher_policy_id: #"6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e",
      treasury_script_hash: #"f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2",
      position_script_hash: #"702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86",
      share_policy_id: #"2d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c425",
      oracle_policy_id: #"f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9",
      oracle_token_name: "oracle_token_name",
      admin_fee_percent: 500,
      // ^ base 10_000
      envelope_amount: 2_000_000,
      candidates: ["cand_1", "cand_2"],
    }
  let project_info_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let project_info_input =
    Input {
      output_reference: project_info_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(project_info_nft_policy_id, project_info_nft_tn, 1),
        datum: InlineDatum(project_info_datum),
        reference_script: None,
      },
    }
  let mint = assets.from_asset(share_policy_id, "cand_1", 10)
  let pos_datum =
    PositionDatum {
      pos_user_pkh,
      pos_user_stake_key,
      pos_type: BuyPos,
      pos_amount: 10,
      pos_batcher_fee: 300_000,
      pos_candidate: "cand_1",
    }
  let pos_out =
    Output {
      address: from_script(project_info_datum.position_script_hash),
      value: mint
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            10 * ( multiplier + project_info_datum.admin_fee_percent ) * decimals / multiplier,
          )
        |> assets.merge(assets.from_lovelace(2_300_000)),
      datum: InlineDatum(pos_datum),
      reference_script: None,
    }
  let tx =
    Transaction {
      inputs: [],
      reference_inputs: [project_info_input],
      outputs: [pos_out],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let params =
    ShareParams {
      project_info_nft: project_info_nft_asset,
      project_prediction_nft: project_prediction_nft_asset,
    }
  let redeemer = Buy { project_info_ref_idx: 0 }
  project_shares.mint(params, redeemer, share_policy_id, tx)
}
