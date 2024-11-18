use aiken/collection/list
use bodega/types.{
  OracleDatum, PositionDatum, ProjectInfoDatum, ProjectPredictionDatum,
  ProjectPredictionParams,
}
use bodega/utils.{
  decimals, find_license_deadline, find_posix_time_range, multiplier,
}
use cardano/address
use cardano/assets.{flatten}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}

pub type ProjectPredictionRedeemer {
  Apply {
    own_input_idx: Int,
    own_output_idx: Int,
    project_info_idx: Int,
    license_idx: Int,
    pos_indices: List<(Int, Int)>,
  }
  Reward {
    own_input_idx: Int,
    own_output_idx: Int,
    project_info_idx: Int,
    oracle_ref_input_idx: Int,
    license_idx: Int,
    pos_indices: List<(Int, Int)>,
  }
  Refund {
    own_input_idx: Int,
    own_output_idx: Int,
    license_idx: Int,
    pos_indices: List<(Int, Int)>,
  }
}

validator project_prediction(params: ProjectPredictionParams) {
  spend(
    option_datum: Option<ProjectPredictionDatum>,
    redeemer: ProjectPredictionRedeemer,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    expect Some(datum) = option_datum
    let own_input_datum: ProjectPredictionDatum = datum
    when redeemer is {
      Apply {
        own_input_idx,
        own_output_idx,
        project_info_idx,
        license_idx,
        pos_indices,
      } -> {
        let Transaction {
          inputs,
          reference_inputs,
          outputs,
          validity_range,
          ..
        } = self
        expect Some(Input { output: Output { value: batcher_value, .. }, .. }) =
          list.at(inputs, license_idx)
        expect Some(project_info_ref_input) =
          list.at(reference_inputs, project_info_idx)
        expect
          assets.quantity_of(
            project_info_ref_input.output.value,
            params.project_info_nft.policy_id,
            params.project_info_nft.asset_name,
          ) == 1
        expect InlineDatum(project_info_inline_datum) =
          project_info_ref_input.output.datum
        expect project_info_datum: ProjectInfoDatum = project_info_inline_datum
        let license_deadline =
          find_license_deadline(
            project_info_datum.batcher_policy_id,
            batcher_value,
          )
        let (_start_valid_time_range, end_valid_time_range) =
          find_posix_time_range(validity_range)
        expect license_deadline >= end_valid_time_range
        expect Some(own_input) = list.at(inputs, own_input_idx)
        expect Some(own_output) = list.at(outputs, own_output_idx)
        expect own_input.output.address == own_output.address
        expect InlineDatum(own_output_inline_datum) = own_output.datum
        expect own_output_datum: ProjectPredictionDatum =
          own_output_inline_datum
        expect
          assets.quantity_of(
            own_input.output.value,
            params.project_prediction_nft.policy_id,
            params.project_prediction_nft.asset_name,
          ) == 1
        expect
          assets.quantity_of(
            own_output.value,
            params.project_prediction_nft.policy_id,
            params.project_prediction_nft.asset_name,
          ) == 1
        let (total_in_pos_values, total_fee) =
          list.foldl(
            pos_indices,
            (assets.zero, 0),
            fn(curr, acc) {
              let (in_idx, out_idx) = curr
              let (cur_val, cur_total_fee) = acc
              expect Some(in) = list.at(inputs, in_idx)
              expect Some(out) = list.at(outputs, out_idx)
              expect InlineDatum(pos_inline_datum) = in.output.datum
              expect pos_datum: PositionDatum = pos_inline_datum
              let user_address =
                address.from_verification_key(pos_datum.pos_user_pkh)
                  |> address.with_delegation_key(pos_datum.pos_user_stake_key)
              expect user_address == out.address
              expect
                list.has(project_info_datum.candidates, pos_datum.pos_candidate)
              let num_candidate_shares =
                assets.quantity_of(
                  in.output.value,
                  project_info_datum.share_policy_id,
                  pos_datum.pos_candidate,
                )
              expect
                [
                  (
                    assets.ada_policy_id,
                    assets.ada_asset_name,
                    project_info_datum.envelope_amount,
                  ),
                  (
                    project_info_datum.share_policy_id,
                    pos_datum.pos_candidate,
                    num_candidate_shares,
                  ),
                ] == assets.flatten(out.value)
              (
                assets.merge(cur_val, in.output.value),
                cur_total_fee + pos_datum.pos_amount * project_info_datum.admin_fee_percent * decimals / multiplier,
              )
            },
          )
        expect
          own_output_datum.total_fee >= own_input_datum.total_fee + total_fee
        let in_prediction_length = list.length(own_input_datum.predictions)
        expect in_prediction_length == list.length(own_output_datum.predictions)
        let zip_in_out =
          list.zip(own_input_datum.predictions, own_output_datum.predictions)
        expect in_prediction_length == list.length(zip_in_out)
        list.foldr(
          zip_in_out,
          True,
          fn(in_out: (Pair<ByteArray, Int>, Pair<ByteArray, Int>), acc) {
            let (Pair(in_cand, in_amount), Pair(out_cand, out_amount)) = in_out
            expect in_cand == out_cand
            let apply_amount =
              assets.quantity_of(
                total_in_pos_values,
                project_info_datum.share_policy_id,
                in_cand,
              )

            in_amount + apply_amount == out_amount && acc
          },
        )
      }
      Reward {
        own_input_idx,
        own_output_idx,
        project_info_idx,
        oracle_ref_input_idx,
        license_idx,
        pos_indices,
      } -> {
        let Transaction {
          inputs,
          reference_inputs,
          outputs,
          mint,
          validity_range,
          ..
        } = self
        expect Some(Input { output: Output { value: batcher_value, .. }, .. }) =
          list.at(inputs, license_idx)
        expect Some(project_info_ref_input) =
          list.at(reference_inputs, project_info_idx)
        expect
          assets.quantity_of(
            project_info_ref_input.output.value,
            params.project_info_nft.policy_id,
            params.project_info_nft.asset_name,
          ) == 1
        expect InlineDatum(project_info_inline_datum) =
          project_info_ref_input.output.datum
        expect project_info_datum: ProjectInfoDatum = project_info_inline_datum
        expect Some(oracle_ref_input) =
          list.at(reference_inputs, oracle_ref_input_idx)
        expect
          assets.quantity_of(
            oracle_ref_input.output.value,
            project_info_datum.oracle_policy_id,
            project_info_datum.oracle_token_name,
          ) == 1
        expect InlineDatum(oracle_inline_datum) = oracle_ref_input.output.datum
        expect oracle_datum: OracleDatum = oracle_inline_datum
        let license_deadline =
          find_license_deadline(
            project_info_datum.batcher_policy_id,
            batcher_value,
          )
        let (_start_valid_time_range, end_valid_time_range) =
          find_posix_time_range(validity_range)
        expect license_deadline >= end_valid_time_range
        expect Some(own_input) = list.at(inputs, own_input_idx)
        expect Some(own_output) = list.at(outputs, own_output_idx)
        expect own_input.output.address == own_output.address
        expect InlineDatum(own_output_inline_datum) = own_output.datum
        expect own_output_datum: ProjectPredictionDatum =
          own_output_inline_datum
        expect
          assets.quantity_of(
            own_input.output.value,
            params.project_prediction_nft.policy_id,
            params.project_prediction_nft.asset_name,
          ) == 1
        expect
          assets.quantity_of(
            own_output.value,
            params.project_prediction_nft.policy_id,
            params.project_prediction_nft.asset_name,
          ) == 1
        let (total_shares, win_shares) =
          list.foldr(
            own_input_datum.predictions,
            (0, 0),
            fn(Pair(cand, amount), acc) {
              let (cur_total_shares, cur_win_shares) = acc
              (
                cur_total_shares + amount,
                if oracle_datum.candidate == cand {
                  cur_win_shares + amount
                } else {
                  cur_win_shares
                },
              )
            },
          )
        let (total_in_pos_values, total_reward, total_shares, total_fee) =
          list.foldl(
            pos_indices,
            (assets.zero, 0, 0, 0),
            fn(curr, acc) {
              let (in_idx, out_idx) = curr
              let (cur_val, cur_reward, cur_num_shares, cur_total_fee) = acc
              expect Some(in) = list.at(inputs, in_idx)
              expect Some(out) = list.at(outputs, out_idx)
              expect InlineDatum(pos_inline_datum) = in.output.datum
              expect pos_datum: PositionDatum = pos_inline_datum
              let user_address =
                address.from_verification_key(pos_datum.pos_user_pkh)
                  |> address.with_delegation_key(pos_datum.pos_user_stake_key)
              expect user_address == out.address
              expect
                list.has(project_info_datum.candidates, pos_datum.pos_candidate)
              expect pos_datum.pos_candidate == oracle_datum.candidate
              let num_candidate_shares =
                assets.quantity_of(
                  in.output.value,
                  project_info_datum.share_policy_id,
                  pos_datum.pos_candidate,
                )
              let fee =
                pos_datum.pos_amount * project_info_datum.admin_fee_percent * decimals / multiplier
              let reward =
                num_candidate_shares * total_shares * decimals / win_shares - fee
              if project_info_datum.payment_policy_id == assets.ada_policy_id {
                expect
                  [
                    (
                      assets.ada_policy_id,
                      assets.ada_asset_name,
                      project_info_datum.envelope_amount + reward,
                    ),
                  ] == assets.flatten(out.value)
              } else {
                expect
                  [
                    (
                      assets.ada_policy_id,
                      assets.ada_asset_name,
                      project_info_datum.envelope_amount,
                    ),
                    (
                      project_info_datum.payment_policy_id,
                      project_info_datum.payment_token_name,
                      reward,
                    ),
                  ] == assets.flatten(out.value)
              }
              (
                assets.merge(cur_val, in.output.value),
                cur_reward + reward,
                cur_num_shares + num_candidate_shares,
                cur_total_fee + fee,
              )
            },
          )
        expect
          own_input_datum.total_fee + total_fee == own_output_datum.total_fee
        let flatten_own_output_value = assets.flatten(own_output.value)
        expect list.length(flatten_own_output_value) <= 3
        let input_lovelace = assets.lovelace_of(own_input.output.value)
        let output_lovelace = assets.lovelace_of(own_output.value)
        if project_info_datum.payment_policy_id == assets.ada_policy_id {
          expect input_lovelace == output_lovelace + total_reward
        } else {
          expect input_lovelace == output_lovelace
          let input_payment =
            assets.quantity_of(
              own_input.output.value,
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
            )
          let output_payment =
            assets.quantity_of(
              own_output.value,
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
            )
          expect input_payment == output_payment + total_reward
        }
        expect
          assets.quantity_of(
            total_in_pos_values,
            project_info_datum.share_policy_id,
            oracle_datum.candidate,
          ) == total_shares
        expect
          [
            (
              project_info_datum.share_policy_id,
              oracle_datum.candidate,
              -total_shares,
            ),
          ] == flatten(mint)
        let in_prediction_length = list.length(own_input_datum.predictions)
        expect in_prediction_length == list.length(own_output_datum.predictions)
        let zip_in_out =
          list.zip(own_input_datum.predictions, own_output_datum.predictions)
        expect in_prediction_length == list.length(zip_in_out)
        list.foldr(
          zip_in_out,
          True,
          fn(in_out: (Pair<ByteArray, Int>, Pair<ByteArray, Int>), acc) {
            let (Pair(in_cand, in_amount), Pair(out_cand, out_amount)) = in_out
            expect in_cand == out_cand
            if in_cand == oracle_datum.candidate {
              in_amount == out_amount - total_shares && acc
            } else {
              in_amount == out_amount && acc
            }
          },
        )
      }

      Refund { .. } -> True
    }
  }

  else(_) {
    fail
  }
}
